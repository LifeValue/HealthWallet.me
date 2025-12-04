
import 'package:flutter/material.dart';

class SaveFhirMediaDialog extends StatefulWidget {
  final int documentCount;

  const SaveFhirMediaDialog({
    super.key,
    required this.documentCount,
  });

  @override
  State<SaveFhirMediaDialog> createState() => _SaveFhirMediaDialogState();
}

class _SaveFhirMediaDialogState extends State<SaveFhirMediaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdController = TextEditingController();
  final _encounterIdController = TextEditingController();
  final _titleController = TextEditingController();
  final _sourceIdController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _sourceIdController.text = 'wallet';
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _encounterIdController.dispose();
    _titleController.dispose();
    _sourceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save as FHIR Media Records'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save ${widget.documentCount} scan${widget.documentCount > 1 ? 's' : ''} as FHIR Media resource${widget.documentCount > 1 ? 's' : ''} in your medical records.',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),


                TextFormField(
                  controller: _patientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Patient MRN *',
                    hintText: 'e.g., MRN-12345',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'MRN is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),


                TextFormField(
                  controller: _sourceIdController,
                  decoration: const InputDecoration(
                    labelText: 'Source ID',
                    hintText: 'e.g., wallet',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.source),
                  ),
                ),
                const SizedBox(height: 12),


                TextFormField(
                  controller: _encounterIdController,
                  decoration: const InputDecoration(
                    labelText: 'Encounter ID (Optional)',
                    hintText: 'e.g., encounter-456',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_information),
                  ),
                ),
                const SizedBox(height: 12),


                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Scan Title (Optional)',
                    hintText: 'e.g., Lab Results, X-Ray Images',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),


                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'FHIR Media Records',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Scans will be saved as FHIR Media resources in your medical records timeline and can be referenced in encounters.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _saveAsMedia,
          icon: const Icon(Icons.save),
          label: const Text('Save to Records'),
        ),
      ],
    );
  }

  void _saveAsMedia() {
    if (_formKey.currentState!.validate()) {
      final result = SaveFhirMediaResult(
        patientId: _patientIdController.text.trim(),
        sourceId: _sourceIdController.text.trim().isNotEmpty
            ? _sourceIdController.text.trim()
            : 'wallet',
        encounterId: _encounterIdController.text.trim().isNotEmpty
            ? _encounterIdController.text.trim()
            : null,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
      );

      Navigator.of(context).pop(result);
    }
  }
}

class SaveFhirMediaResult {
  final String patientId;
  final String sourceId;
  final String? encounterId;
  final String? title;

  const SaveFhirMediaResult({
    required this.patientId,
    required this.sourceId,
    this.encounterId,
    this.title,
  });
}
