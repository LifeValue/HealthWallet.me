import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/fhir_bundle_builder.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: FHIRBundleBuilder)
class FHIRBundleBuilderImpl implements FHIRBundleBuilder {
  final AppDatabase _appDatabase;

  FHIRBundleBuilderImpl(this._appDatabase);

  @override
  Future<Map<String, dynamic>> buildBundle({
    required List<String> resourceIds,
    String? sourceId,
    bool requirePatient = false,
  }) async {
    if (resourceIds.isEmpty) {
      throw Exception('At least one resource must be selected');
    }

    // Fetch selected resources
    final resources = await _fetchResources(resourceIds, sourceId);

    if (resources.isEmpty) {
      throw Exception('No resources found for selected IDs');
    }

    // Check if Patient is in selected resources
    final patientInSelected = resources.any((r) => r.resourceType == 'Patient');

    // Ensure Patient resource (if required or for minimal info)
    final patientResource = await _ensurePatientResource(
      resources,
      sourceId,
      requirePatient: requirePatient,
    );

    if (requirePatient && patientResource == null) {
      throw Exception('Patient resource is required but not found');
    }

    // Log Patient resource status for debugging
    if (patientResource != null) {
      logger.d('Patient resource found: ${patientResource.resourceId}, inSelected: $patientInSelected, requirePatient: $requirePatient');
    } else {
      logger.d('No Patient resource found (requirePatient: $requirePatient)');
    }

    // Add Patient to resources list if not already there (for reference resolution)
    final allResources = <FhirResourceLocalDto>[];
    if (patientResource != null &&
        !resources.any((r) => r.id == patientResource.id)) {
      allResources.add(patientResource);
    }
    allResources.addAll(resources);

    // Parse resources and build entries
    final entries = <Map<String, dynamic>>[];
    final processedIds = <String>{};
    int resourceIndex = 0;

    // Handle Patient resource
    if (patientResource != null) {
      if (requirePatient || patientInSelected) {
        // Add full Patient resource
        final patientJson =
            jsonDecode(patientResource.resourceRaw) as Map<String, dynamic>;
        entries.add({
          'fullUrl': 'resource:$resourceIndex',
          'resource': patientJson,
        });
        processedIds.add(patientResource.id);
        resourceIndex++;
      } else {
        // Add minimal Patient info (Name + Age)
        final minimalPatient = _extractMinimalPatientInfo(patientResource);
        if (minimalPatient != null) {
          logger.d('Adding minimal Patient info to bundle: ${jsonEncode(minimalPatient)}');
          entries.add({
            'fullUrl': 'resource:$resourceIndex',
            'resource': minimalPatient,
          });
          resourceIndex++;
        } else {
          logger.w('Failed to extract minimal Patient info from Patient resource');
        }
      }
    }

    // Add other resources
    for (final resource in resources) {
      if (processedIds.contains(resource.id)) continue;

      final resourceJson =
          jsonDecode(resource.resourceRaw) as Map<String, dynamic>;

      // Resolve references to use fullUrl format - pass allResources including Patient
      final resolvedResource =
          await _resolveReferences(resourceJson, allResources, sourceId);

      entries.add({
        'fullUrl': 'resource:$resourceIndex',
        'resource': resolvedResource,
      });
      processedIds.add(resource.id);
      resourceIndex++;
    }

    // Build FHIR Bundle
    return {
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': entries,
    };
  }

  Future<List<FhirResourceLocalDto>> _fetchResources(
    List<String> resourceIds,
    String? sourceId,
  ) async {
    final resources = <FhirResourceLocalDto>[];

    for (final id in resourceIds) {
      final query = _appDatabase.select(_appDatabase.fhirResource)
        ..where((f) => f.id.equals(id));

      if (sourceId != null) {
        query.where((f) => f.sourceId.equals(sourceId));
      }

      final resource = await query.getSingleOrNull();
      if (resource != null) {
        resources.add(resource);
      }
    }

    return resources;
  }

  Future<FhirResourceLocalDto?> _ensurePatientResource(
    List<FhirResourceLocalDto> resources,
    String? sourceId, {
    required bool requirePatient,
  }) async {
    // Check if Patient is already in the list
    try {
      final patient = resources.firstWhere(
        (r) => r.resourceType == 'Patient',
      );
      return patient;
    } catch (e) {
      // Patient not in list, need to find it
    }

    // Try to find Patient resource by subjectId
    final subjectIds =
        resources.map((r) => r.subjectId).whereType<String>().where((id) => id.isNotEmpty).toSet();

    // Also try to extract subject ID from resource references
    for (final resource in resources) {
      try {
        final resourceJson = jsonDecode(resource.resourceRaw) as Map<String, dynamic>;
        final subject = resourceJson['subject'] as Map<String, dynamic>?;
        if (subject != null) {
          final reference = subject['reference'] as String?;
          if (reference != null && reference.isNotEmpty) {
            // Extract ID from reference (format: "Patient/123" or "urn:uuid:...")
            String? extractedId;
            if (reference.startsWith('urn:uuid:')) {
              extractedId = reference.substring(9);
            } else if (reference.contains('/')) {
              final parts = reference.split('/');
              if (parts.length == 2 && parts[0] == 'Patient') {
                extractedId = parts[1];
              }
            }
            if (extractedId != null && extractedId.isNotEmpty) {
              subjectIds.add(extractedId);
            }
          }
        }
      } catch (e) {
        // Skip if parsing fails
      }
    }

    // If we have subject IDs, try to find Patient
    if (subjectIds.isNotEmpty) {
      // Try each subject ID until we find a Patient
      for (final subjectId in subjectIds) {
        final query = _appDatabase.select(_appDatabase.fhirResource)
          ..where((f) => f.resourceType.equals('Patient'))
          ..where((f) => f.resourceId.equals(subjectId))
          ..limit(1);

        if (sourceId != null) {
          query.where((f) => f.sourceId.equals(sourceId));
        }

        final patient = await query.getSingleOrNull();
        if (patient != null) {
          return patient;
        }
      }
    }

    // If no Patient found via subject references, try to find any Patient resource
    // (for cases where we want to include minimal Patient info)
    if (!requirePatient) {
      // Try to find Patient from any source (for minimal info)
      // We prioritize finding Patient even if sourceId doesn't match
      // because minimal Patient info is helpful context
      final query = _appDatabase.select(_appDatabase.fhirResource)
        ..where((f) => f.resourceType.equals('Patient'))
        ..orderBy([(f) => OrderingTerm.desc(f.date)]) // Get most recent Patient
        ..limit(1);
      return await query.getSingleOrNull();
    }

    // Patient is required but not found
    throw Exception('No Patient resource found and no subject references');
  }

  /// Extract minimal Patient information (Name + Age) from Patient resource
  /// Returns a simplified Patient resource with only name and birthDate fields
  Map<String, dynamic>? _extractMinimalPatientInfo(
    FhirResourceLocalDto patientResource,
  ) {
    try {
      final patientJson =
          jsonDecode(patientResource.resourceRaw) as Map<String, dynamic>;

      logger.d('Extracting minimal Patient info from resource: ${patientResource.resourceId}');

      // Extract name (first name entry)
      final nameList = patientJson['name'] as List<dynamic>?;
      Map<String, dynamic>? name;
      if (nameList != null && nameList.isNotEmpty) {
        final firstNameEntry = nameList.first as Map<String, dynamic>;
        // Create minimal name object with only given and family
        final given = firstNameEntry['given'] as List<dynamic>?;
        final family = firstNameEntry['family'] as String?;
        
        if ((given != null && given.isNotEmpty) || (family != null && family.isNotEmpty)) {
          name = {
            'use': firstNameEntry['use'] ?? 'official',
            if (given != null && given.isNotEmpty) 'given': given,
            if (family != null && family.isNotEmpty) 'family': family,
          };
          logger.d('Extracted Patient name: given=${given?.join(' ')}, family=$family');
        }
      }

      // Extract birthDate
      final birthDate = patientJson['birthDate'] as String?;
      logger.d('Extracted Patient birthDate: $birthDate');

      // If we have at least name or birthDate, create minimal Patient
      if (name != null || birthDate != null) {
        final minimalPatient = <String, dynamic>{
          'resourceType': 'Patient',
          'id': patientResource.resourceId ?? '',
        };

        if (name != null) {
          minimalPatient['name'] = [name];
        }

        if (birthDate != null) {
          minimalPatient['birthDate'] = birthDate;
        }

        logger.d('Created minimal Patient: ${jsonEncode(minimalPatient)}');
        return minimalPatient;
      }

      logger.w('No name or birthDate found in Patient resource, cannot create minimal Patient');
      return null;
    } catch (e) {
      logger.e('Failed to extract minimal Patient info: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _resolveReferences(
    Map<String, dynamic> resource,
    List<FhirResourceLocalDto> availableResources,
    String? sourceId,
  ) async {
    final resolved = Map<String, dynamic>.from(resource);

    // Resolve references recursively
    await _resolveReferencesRecursive(
        resolved, availableResources, {}, sourceId);

    return resolved;
  }

  Future<void> _resolveReferencesRecursive(
    Map<String, dynamic> resource,
    List<FhirResourceLocalDto> availableResources,
    Set<String> visited,
    String? sourceId,
  ) async {
    for (final entry in resource.entries) {
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        if (value.containsKey('reference')) {
          final reference = value['reference'] as String;

          // Skip if already visited
          if (visited.contains(reference)) continue;
          visited.add(reference);

          // Find referenced resource in available resources first
          FhirResourceLocalDto? referencedResource;

          if (reference.startsWith('urn:uuid:')) {
            final uuid = reference.substring(9);
            try {
              referencedResource = availableResources.firstWhere(
                (r) => r.resourceId == uuid,
              );
            } catch (e) {
              // Not found in available resources, try to fetch from database
              referencedResource =
                  await _fetchReferencedResource(reference, sourceId);
            }
          } else if (reference.contains('/')) {
            final parts = reference.split('/');
            if (parts.length == 2) {
              try {
                referencedResource = availableResources.firstWhere(
                  (r) => r.resourceType == parts[0] && r.resourceId == parts[1],
                );
              } catch (e) {
                // Not found in available resources, try to fetch from database
                referencedResource =
                    await _fetchReferencedResource(reference, sourceId);
              }
            }
          }

          if (referencedResource != null) {
            // Add to available resources if not already there
            if (!availableResources
                .any((r) => r.id == referencedResource!.id)) {
              availableResources.add(referencedResource);
            }

            final referencedJson = jsonDecode(referencedResource.resourceRaw)
                as Map<String, dynamic>;
            // Update reference to use fullUrl format
            final index = availableResources.indexOf(referencedResource);
            value['reference'] = 'resource:$index';

            // Recursively resolve references in the referenced resource
            await _resolveReferencesRecursive(
                referencedJson, availableResources, visited, sourceId);
          }
          // If we can't find the referenced resource, keep the original reference
          // This is more lenient - we don't fail, just keep the reference as-is
        } else {
          // Recursively process nested objects
          await _resolveReferencesRecursive(
              value, availableResources, visited, sourceId);
        }
      } else if (value is List) {
        // Process list items
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            await _resolveReferencesRecursive(
                item, availableResources, visited, sourceId);
          }
        }
      }
    }
  }

  Future<FhirResourceLocalDto?> _fetchReferencedResource(
    String reference,
    String? sourceId,
  ) async {
    if (reference.startsWith('urn:uuid:')) {
      final uuid = reference.substring(9);
      final query = _appDatabase.select(_appDatabase.fhirResource)
        ..where((f) => f.resourceId.equals(uuid))
        ..limit(1);

      if (sourceId != null) {
        query.where((f) => f.sourceId.equals(sourceId));
      }

      return await query.getSingleOrNull();
    } else if (reference.contains('/')) {
      final parts = reference.split('/');
      if (parts.length == 2) {
        final query = _appDatabase.select(_appDatabase.fhirResource)
          ..where((f) => f.resourceType.equals(parts[0]))
          ..where((f) => f.resourceId.equals(parts[1]))
          ..limit(1);

        if (sourceId != null) {
          query.where((f) => f.sourceId.equals(sourceId));
        }

        return await query.getSingleOrNull();
      }
    }

    return null;
  }
}

