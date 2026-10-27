// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get onboardingWelcomeTitle => '¡una Cartera de Salud para Ti!';

  @override
  String get onboardingWelcomeSubtitle =>
      '<link>HealthWallet.me</link> ya se conecta a más de 100.000 proveedores de salud estadounidenses, y estamos expandiendo a nuevos países.';

  @override
  String get onboardingWelcomeDescription =>
      'Agrega registros de cualquier proveedor, importa documentos manualmente o solicita soporte para tu país.';

  @override
  String get onboardingRecordsTitle => 'Tu salud, siempre sincronizada';

  @override
  String get onboardingRecordsSubtitle =>
      '<link>HealthWallet.me</link> te ofrece formas flexibles de reunir todo tu historial médico:';

  @override
  String get onboardingRecordsDescription =>
      '• Escanea documentos con la cámara de tu teléfono\n• Sube PDFs, imágenes o archivos de laboratorio directamente\n• Importa registros compartiendo directamente con <link>HealthWallet.me</link> desde cualquier app de tu teléfono.\n• Escanea el código QR de Fasten Health OnPrem y obtén todos los registros de salud de EE.UU. en tu wallet.';

  @override
  String get onboardingRecordsContent =>
      '• Escanea documentos con la cámara de tu teléfono\n• Sube PDFs, imágenes o archivos de laboratorio directamente\n• Importa registros compartiendo directamente con <link>HealthWallet.me</link> desde cualquier app de tu teléfono.\n• Escanea el código QR de <link>Fasten Health OnPrem</link> y obtén todos los registros de salud de EE.UU. en tu wallet.';

  @override
  String get onboardingRecordsBottom =>
      'Todo se organiza de forma segura en tu dispositivo.';

  @override
  String get onboardingRequestIntegration => 'Solicitar una integración';

  @override
  String get onboardingScanButton => 'Escanear';

  @override
  String get onboardingSyncTitle => 'Privado por diseño';

  @override
  String get onboardingSyncSubtitle =>
      'Tus datos de salud te pertenecen solo a ti.';

  @override
  String get onboardingSyncDescription =>
      'Creemos que tu información de salud sensible nunca debería estar en el servidor de una empresa. Tus datos están encriptados y almacenados exclusivamente en tu dispositivo, lo que significa que eres el único con acceso.';

  @override
  String get homeHi => 'Hola, ';

  @override
  String get homeVitalSigns => 'Signos vitales';

  @override
  String get homeSource => 'Fuente:';

  @override
  String get homeNA => 'N/A';

  @override
  String get dashboardTitle => 'Tablero';

  @override
  String get recordsTitle => 'Registros';

  @override
  String get goToRecords => 'Ir a registros';

  @override
  String get syncTitle => 'Sincronizar';

  @override
  String get syncSuccessful => '¡Sincronización exitosa!';

  @override
  String get syncDataLoadedSuccessfully =>
      'Tus registros médicos han sido sincronizados. Serás redirigido a la página de inicio.';

  @override
  String get cancelSyncTitle => '¿Cancelar sincronización?';

  @override
  String get cancelSyncMessage =>
      '¿Estás seguro de que quieres cancelar la sincronización? Esto detendrá el proceso de sincronización actual.';

  @override
  String get yesCancel => 'Sí, cancelar';

  @override
  String get continueSync => 'Continuar sincronización';

  @override
  String get tryAgain => 'Intentar de nuevo';

  @override
  String get searchRecordsHint => 'Buscar registros, médicos, ubicaciones...';

  @override
  String get patientId => 'ID de paciente: ';

  @override
  String get age => 'Edad';

  @override
  String get sex => 'Sexo';

  @override
  String get bloodType => 'Tipo de sangre';

  @override
  String get theme => 'Tema';

  @override
  String get authenticate => 'Autenticar';

  @override
  String get biometricAuthentication => 'Autenticación biométrica';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get setupDeviceSecurity => 'Configurar seguridad del dispositivo';

  @override
  String get deviceSecurityMessage =>
      'Tu dispositivo no tiene configuración de seguridad. Por tu seguridad, por favor configura la seguridad del dispositivo antes de usar esta aplicación:';

  @override
  String get deviceSettingsStep1 => 'Ve a la configuración de tu dispositivo';

  @override
  String get deviceSettingsStep2 => 'Navega a Seguridad o Pantalla de bloqueo';

  @override
  String get deviceSettingsStep3 =>
      'Configura un bloqueo de pantalla (PIN, patrón o contraseña)';

  @override
  String get deviceSettingsStep4 =>
      'Opcionalmente agrega huella dactilar o desbloqueo facial para mayor comodidad';

  @override
  String get deviceSecurityReturnMessage =>
      'Después de configurar la seguridad del dispositivo, regresa a esta aplicación e inténtalo de nuevo.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get openSettings => 'Abrir configuración';

  @override
  String get settingsNotAvailable => 'Configuración no disponible';

  @override
  String get settingsNotAvailableMessage =>
      'No se pudo abrir la configuración del dispositivo automáticamente. Por favor hazlo manualmente:\n\n1. Abrir Configuración\n2. Ir a Seguridad → Biometría\n3. Agregar huella dactilar o desbloqueo facial\n4. Regresar a esta aplicación e intentar de nuevo';

  @override
  String get ok => 'OK';

  @override
  String get or => 'o';

  @override
  String get connect => 'Conectar';

  @override
  String get loadDemoData => 'Cargar datos de demostración';

  @override
  String get noMedicalRecordsYet => 'Aún no hay registros médicos';

  @override
  String get loadDemoDataMessage =>
      'Carga datos de demostración para explorar la aplicación o sincroniza tus registros médicos reales';

  @override
  String get retry => 'Reintentar';

  @override
  String get pleaseEnterSourceName => 'Por favor ingresa un nombre de fuente';

  @override
  String get selectBirthDate => 'Seleccionar fecha de nacimiento';

  @override
  String get years => 'años';

  @override
  String get male => 'Masculino';

  @override
  String get female => 'Femenino';

  @override
  String get preferNotToSay => 'Prefiero no decir';

  @override
  String get errorUpdatingSourceLabel =>
      'Error al actualizar etiqueta de fuente';

  @override
  String get getStarted => 'Empezar';

  @override
  String get failedToUpdateDisplayName =>
      'Error al actualizar nombre para mostrar';

  @override
  String get actionCannotBeUndone => 'Esta acción no se puede deshacer.';

  @override
  String get deleteSourceConfirmPrefix => 'Esto eliminará permanentemente ';

  @override
  String get deleteSourceConfirmSuffix =>
      ' y todos sus registros. Para confirmar, escribe el nombre de la fuente a continuación.';

  @override
  String get deleteRecordConfirm =>
      '¿Estás seguro de que quieres eliminar este registro?';

  @override
  String get deleteNoteConfirm =>
      '¿Estás seguro de que quieres eliminar esta nota?';

  @override
  String get deleteAttachmentConfirm =>
      '¿Estás seguro de que quieres eliminar este archivo adjunto?';

  @override
  String deleteRecordsConfirm(int count) {
    return '¿Estás seguro de que quieres eliminar $count elementos?';
  }

  @override
  String get editSourceLabel => 'Editar etiqueta de fuente';

  @override
  String get saveDetails => 'Guardar detalles';

  @override
  String get editDetails => 'Editar detalles';

  @override
  String get done => 'Hecho';

  @override
  String get page => 'Página';

  @override
  String get reorderPages => 'Reordenar páginas';

  @override
  String get attachments => 'Archivos adjuntos';

  @override
  String get noFilesAttached => 'Este registro no tiene archivos adjuntos';

  @override
  String get attachFile => 'Adjuntar archivo';

  @override
  String get overview => 'Resumen';

  @override
  String get recentRecords => 'Registros recientes';

  @override
  String get displayName => 'Nombre para mostrar';

  @override
  String get unknownSource => 'Fuente desconocida';

  @override
  String get desktopSyncAndBackup => 'Sincronización y respaldo de escritorio';

  @override
  String get desktopSyncDescription =>
      'Sincroniza y respalda tus registros de salud.\nEntrega documentos para procesamiento digital en tu escritorio.';

  @override
  String get processOnDesktop => 'Procesar en el escritorio';

  @override
  String get continueImporting => 'Continuar importando';

  @override
  String get noAiModel => 'Sin modelo de IA';

  @override
  String get noAiModelOnDesktop =>
      'No hay modelo de IA en el escritorio. Por favor, descarga el modelo de IA en tu aplicación de escritorio primero.';

  @override
  String get syncMedicalRecords => 'Sincronizar registros médicos';

  @override
  String get lastSynced => 'Última sincronización';

  @override
  String get tapToSelectPatient => 'Toca para seleccionar paciente';

  @override
  String get preferences => 'Preferencias';

  @override
  String get version => 'Versión';

  @override
  String get on => 'Encendido';

  @override
  String get off => 'Apagado';

  @override
  String get confirmDisableBiometric =>
      '¿Estás seguro de que quieres desactivar la autenticación biométrica (FaceID / Código de acceso)?';

  @override
  String get disable => 'Desactivar';

  @override
  String get continueButton => 'Continuar';

  @override
  String get enableBiometricAuth =>
      'Habilitar autenticación biométrica (FaceID / Código de acceso)';

  @override
  String get disableBiometricAuth =>
      'Desactivar autenticación biométrica (FaceID / Código de acceso)';

  @override
  String get patient => 'Paciente';

  @override
  String get noPatientsFound => 'No se encontraron pacientes';

  @override
  String get id => 'ID';

  @override
  String get gender => 'Género';

  @override
  String get loading => 'Cargando...';

  @override
  String get source => 'Fuente';

  @override
  String get records => 'Registros';

  @override
  String get vitals => 'Signos vitales';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get clearAll => 'Limpiar todo';

  @override
  String get save => 'Guardar';

  @override
  String get noRecordsFound => 'No se encontraron registros';

  @override
  String get noRecords => 'Sin registros';

  @override
  String get tryDifferentKeywords =>
      'Intenta buscar con palabras clave diferentes';

  @override
  String get syncingData => 'Sincronizando datos';

  @override
  String get syncingMessage => 'Puede tomar un tiempo. Por favor espera.';

  @override
  String get viewAll => 'Ver todo';

  @override
  String get vitalSigns => 'Signos vitales';

  @override
  String get longPressToReorder =>
      'Mantén presionado para mover y reordenar tarjetas, o filtra para seleccionar cuáles aparecen en tu panel de control.';

  @override
  String get finishProcessing => 'Finalizar procesamiento';

  @override
  String get finishProcessingMessage =>
      '¿Estás seguro de que quieres finalizar esta sesión de procesamiento?';

  @override
  String get finishProcessingWarning => 'Esto borrará la sesión actual.';

  @override
  String get fieldCannotBeEmpty => 'Este campo no puede estar vacío';

  @override
  String get selectDate => 'Seleccionar fecha';

  @override
  String get attachToEncounter => 'Adjuntar a encuentro';

  @override
  String get continueProcessing => 'Continuar procesamiento';

  @override
  String get recordsSavedTitle => 'Guardado exitosamente';

  @override
  String get whatNextQuestion => '¿Qué te gustaría hacer a continuación?';

  @override
  String get continueScanning => 'Continuar escaneando';

  @override
  String get effectiveDate => 'Fecha de vigencia';

  @override
  String get privacyIntro => 'Tu privacidad es nuestra máxima prioridad.';

  @override
  String get privacyDescription =>
      'es una herramienta simple y segura diseñada para ayudarte a organizar tus registros de salud con facilidad, directamente en tu dispositivo. Esta política explica nuestro compromiso con tu privacidad: no recopilamos tus datos y no te rastreamos. Tienes el control completo.';

  @override
  String get corePrinciple =>
      'Nuestro principio fundamental: tus datos permanecen en tu dispositivo';

  @override
  String get whatInformationHandled => '¿Qué información se maneja?';

  @override
  String get informationWeDoNotCollect =>
      'Información que no recopilamos o accedemos';

  @override
  String get informationYouManage => 'Información que tú administras';

  @override
  String get importingDocuments => 'Importar documentos desde tu dispositivo';

  @override
  String get connectingFastenHealth => 'Conectando a FastenHealth OnPrem';

  @override
  String get howInformationUsed => 'Cómo se usa tu información';

  @override
  String get dataStorageSecurity =>
      'Almacenamiento de datos, seguridad y compartir';

  @override
  String get childrensPrivacy => 'Privacidad de los niños';

  @override
  String get changesToPolicy => 'Cambios a esta política de privacidad';

  @override
  String get contactUs => 'Contáctanos';

  @override
  String get builtWithLove => '¡Construido con amor por Life Value!';

  @override
  String get sourceName => 'Nombre de fuente';

  @override
  String get provideCustomLabel =>
      'Proporciona una etiqueta personalizada para:';

  @override
  String get success => 'Éxito';

  @override
  String get demoDataLoadedSuccessfully =>
      'Los datos de demostración se han cargado exitosamente. Serás redirigido a la página de inicio.';

  @override
  String get documentScanTitle => 'Escanear';

  @override
  String get fromPhoneTab => 'Del teléfono';

  @override
  String get onboardingAiModelTitle => 'Habilitar modelo de IA';

  @override
  String get onboardingAiModelDescription =>
      'Descarga un modelo de IA seguro y en el dispositivo para analizar y organizar automáticamente tus registros de salud. Elige entre dos opciones según tus necesidades y la capacidad del dispositivo. Es una configuración única.\n\n**Tus datos permanecen privados en tu dispositivo.**';

  @override
  String get onboardingAiModelSubtitle =>
      'Desbloquea el escaneo impulsado por IA';

  @override
  String get aiModelReady => '¡IA lista! Puedes empezar a escanear.';

  @override
  String get aiModelDownloading => 'Descargando...';

  @override
  String get aiModelEnableDownload => 'Elegir y descargar';

  @override
  String get aiModelError => 'No se pudo verificar. Inténtalo de nuevo.';

  @override
  String get aiModelMissing => 'No descargado.';

  @override
  String get aiModelTitle => 'Cargar modelo de IA';

  @override
  String get aiModelUnlockTitle => 'Desbloquea el escaneo con IA';

  @override
  String get aiModelUnlockDescription =>
      'Para leer y organizar automáticamente tus documentos médicos, esta función utiliza un modelo de IA seguro y local en tu dispositivo.\n\n**Tus datos permanecen privados en tu dispositivo.**';

  @override
  String get aiModelDownloadInfo =>
      'Para comenzar, elige y descarga una de las dos opciones de IA disponibles. Es una configuración única.';

  @override
  String get setup => 'Configurar';

  @override
  String get patientSetupSubtitle =>
      'Personaliza tu cartera de salud con tu información';

  @override
  String get givenName => 'Nombre';

  @override
  String get familyName => 'Apellido';

  @override
  String get syncPlaceholderTutorialStep1 =>
      'Completa tu perfil para desbloquear todas las funciones.';

  @override
  String get syncPlaceholderTutorialStep2 =>
      '¿No estás listo para importar? Carga datos de demostración para ver cómo se ve la aplicación en acción.';

  @override
  String get syncPlaceholderTutorialStep3 =>
      'Mantén tu cartera de escritorio y móvil actualizada.';

  @override
  String get tapToContinue => 'Toca para continuar';

  @override
  String get homeOnboardingReorderMessage =>
      'Mantén presionado para reordenarlos según tu preferencia.';

  @override
  String get processing => 'Procesamiento';

  @override
  String get sessionNotFound => '¡Sesión no encontrada!';

  @override
  String get preparingPreview => 'Preparando vista previa...';

  @override
  String get processingFailed => 'Procesamiento fallido';

  @override
  String get modelNotFoundError =>
      'Archivo de modelo no encontrado. Descarga el modelo de IA primero.';

  @override
  String get modelCorruptedError =>
      'El archivo del modelo está dañado. Vuelve a descargar el modelo de IA.';

  @override
  String get processingCancelled => 'El procesamiento fue cancelado';

  @override
  String get processingBasicDetails => 'Procesando detalles básicos...';

  @override
  String get processingPages => 'Procesando páginas...';

  @override
  String get extractingPatientInfo =>
      'Extrayendo información del paciente y encuentro.';

  @override
  String get pleaseWait => 'Puede tardar un poco. Por favor espera.';

  @override
  String get focusMode => 'Modo enfoque';

  @override
  String get onlyOneSessionAtTime =>
      'Solo una sesión de procesamiento puede ejecutarse a la vez';

  @override
  String get aiModelNotAvailable => 'El escaneo inteligente no está disponible';

  @override
  String get addResources => 'Agregar recursos';

  @override
  String get addResourcesTitle => 'Agregar recursos';

  @override
  String get chooseResourcesDescription =>
      'Elige los recursos que quieres agregar para el procesamiento.';

  @override
  String get add => 'Agregar';

  @override
  String get allergyIntolerance => 'Intolerancia a alergias';

  @override
  String get condition => 'Condición';

  @override
  String get diagnosticReport => 'Informe de diagnóstico';

  @override
  String get medicationStatement => 'Declaración de medicación';

  @override
  String get observation => 'Observación';

  @override
  String get organization => 'Organización';

  @override
  String get practitioner => 'Profesional';

  @override
  String get procedure => 'Procedimiento';

  @override
  String get tapToViewProgress =>
      'Toca en cualquier lugar para ver el progreso';

  @override
  String screenWillDarkenInSeconds(int remainingSeconds) {
    return 'La pantalla se oscurecerá en $remainingSeconds segundos.';
  }

  @override
  String get screenWillDarkenInZeroSeconds =>
      'La pantalla se oscurecerá en 0 segundos.';

  @override
  String get whileDocumentsProcessed => 'Mientras se procesan tus documentos:';

  @override
  String get doNotLockScreen =>
      'No bloquees la pantalla ni salgas de la aplicación.';

  @override
  String get plugInCharger => 'Conecta el cargador.';

  @override
  String get exitFocusMode => 'Salir del modo enfoque';

  @override
  String get chargerPluggedIn => 'Cargador conectado.';

  @override
  String get plugInChargerEllipsis => 'Conecta el cargador...';

  @override
  String get processingFailedCapacity =>
      'El documento es demasiado grande para el tamaño de contexto actual de IA.';

  @override
  String get processingFailedCapacitySuggestion =>
      'Toca el icono de ajustes arriba y aumenta el tamaño de contexto a 2048 o más, luego reintenta.';

  @override
  String get increaseAiModelCapacity => 'Aumentar capacidad de IA';

  @override
  String get goBack => 'Volver';

  @override
  String get aiModelManage => 'Gestionar opciones de IA';

  @override
  String get aiModelNotSelected => 'Ninguna opción seleccionada';

  @override
  String get aiModelSelect => 'Seleccionar opción';

  @override
  String get aiSettings => 'Ajustes de IA';

  @override
  String get aiSettingsDescription =>
      'Ajusta el rendimiento de IA para tu dispositivo. Los valores recomendados están preseleccionados.';

  @override
  String get setAiTokensUsage => 'Configurar uso de tokens IA';

  @override
  String get tokenUsageDescription =>
      'Controla cuánta capacidad de procesamiento puede usar la IA. Mayor capacidad permite archivos más grandes y tareas más complejas, pero usa más recursos y tarda más.';

  @override
  String get gpuLayersLabel => 'Capas GPU';

  @override
  String get gpuLayersDescription =>
      'Descargar capas del modelo a la GPU para un procesamiento de imágenes más rápido. Más capas = más rápido pero más memoria. Pon 0 si la app se cierra.';

  @override
  String get threadsLabel => 'Hilos CPU';

  @override
  String get threadsDescription =>
      'Número de hilos de CPU para inferencia. Más hilos = más rápido pero más batería.';

  @override
  String get recommended => 'Recomendado';

  @override
  String get tokenPresetLow => 'Bajo';

  @override
  String get tokenPresetMedium => 'Medio';

  @override
  String get tokenPresetHigh => 'Alto';

  @override
  String get tokenPresetCustom => 'Personalizado';

  @override
  String get setTokens => 'Establecer';

  @override
  String get tokens => 'tokens';

  @override
  String get contextSizeLabel => 'Tamaño de contexto';

  @override
  String get contextSizeDescription =>
      'Cantidad de texto que la IA puede procesar a la vez. Un contexto mayor maneja documentos más grandes pero usa más memoria.';

  @override
  String get useVisionLabel => 'Escaneo profundo';

  @override
  String get useVisionDescription =>
      'Lee imágenes para un análisis más profundo (p. ej. escritura a mano). Usa más memoria y requiere un dispositivo más potente.';

  @override
  String get aiModelNotAvailableForDevice => 'No disponible para este teléfono';

  @override
  String get aiModelNotAvailableForDeviceDescription =>
      'Este dispositivo no tiene suficiente memoria para ejecutar el escaneo inteligente.';

  @override
  String get noInternetConnectionTitle => 'Sin conexión a Internet';

  @override
  String get noInternetConnectionDescription =>
      'Por favor, verifica tu conexión a Internet e inténtalo de nuevo.';

  @override
  String get processingStep2NotAvailableTitle =>
      'Escaneo profundo no disponible en este dispositivo';

  @override
  String get processingStep2NotEnoughRam =>
      'Este dispositivo no tiene suficiente memoria para el escaneo profundo. El procesamiento basado en texto sigue disponible y funciona bien para la mayoría de documentos.';

  @override
  String get emergencyContact => 'Contacto telefónico de emergencia';

  @override
  String get rotatePage => 'Rotar';

  @override
  String get deletePage => 'Eliminar';

  @override
  String get deletePageConfirmTitle => 'Eliminar página';

  @override
  String get deletePageConfirmMessage =>
      'Esta página será eliminada del documento.';

  @override
  String get regionAndUnits => 'Idioma y unidades';

  @override
  String get country => 'País';

  @override
  String patientModifiedUpdating(String name) {
    return 'Modificando paciente existente: $name';
  }

  @override
  String patientSavingModified(String name) {
    return 'Guardando paciente modificado: $name';
  }

  @override
  String get dropModificationsTitle => '¿Descartar modificaciones?';

  @override
  String get dropModificationsMessage =>
      'Los cambios realizados en los campos del paciente se descartarán.';

  @override
  String get scanIdCard => 'Escanear DNI o pasaporte';

  @override
  String get scanIdCardDescription =>
      'Completa automáticamente desde tu documento. Los datos permanecen en tu dispositivo.';

  @override
  String get newLabel => 'Nuevo';

  @override
  String get newPatient => 'Nuevo paciente';

  @override
  String patientChangedTo(String name) {
    return 'Cambiado a: $name';
  }

  @override
  String patientMatchFound(String name) {
    return 'Paciente existente: $name';
  }

  @override
  String get language => 'Idioma';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get regionUS => 'US';

  @override
  String get regionEurope => 'Europa';

  @override
  String get regionUK => 'UK';

  @override
  String get medGemmaIncompatibleDevice =>
      'Este modelo requiere más memoria de la que tiene disponible tu dispositivo. Usa el modelo estándar en su lugar.';

  @override
  String get deepScanDownloadTitle => 'Descargar modelo de visión';

  @override
  String deepScanDownloadMessage(int size) {
    return 'El escaneo profundo requiere una descarga adicional (~$size MB). ¿Descargar ahora?';
  }

  @override
  String get shareUnknownDevice => 'Dispositivo desconocido';

  @override
  String get shareViewOnlyBanner =>
      'SOLO LECTURA - Los datos se eliminarán cuando cierres la sesión o salgas del área de proximidad';

  @override
  String get shareViewOnlyBannerViewing =>
      'SOLO LECTURA - Los datos se eliminarán cuando salgas';

  @override
  String get shareInfoBannerMessage =>
      'Los registros compartidos son de solo lectura. Todos los datos se eliminan automáticamente cuando la sesión termina o el límite de tiempo expira.';

  @override
  String get shareTitle => 'Compartir';

  @override
  String get shareFindDevices => 'Buscar dispositivos';

  @override
  String get shareWaiting => 'Esperando...';

  @override
  String get shareConnectingTitle => 'Conectando';

  @override
  String get shareSending => 'Enviando';

  @override
  String get shareReceiving => 'Recibiendo';

  @override
  String get shareSessionActive => 'Sesión activa';

  @override
  String get shareViewingRecords => 'Viendo registros';

  @override
  String get shareComplete => 'Completo';

  @override
  String get shareError => 'Error';

  @override
  String get sharePermissionsRequired => 'Permisos requeridos';

  @override
  String get shareHealthWalletDevice => 'Dispositivo HealthWallet';

  @override
  String get shareInvitationDeclined => 'Invitación rechazada';

  @override
  String get shareSessionComplete => 'Sesión completa';

  @override
  String get shareInvitationDeclinedMessage =>
      'El receptor rechazó tu invitación para ver los registros.';

  @override
  String get shareSessionCompleteMessage =>
      'Todos los datos compartidos han sido eliminados de forma segura de este dispositivo';

  @override
  String get shareBackHome => 'Volver al inicio';

  @override
  String get shareConnectionFailed => 'Conexión fallida';

  @override
  String get shareUnableToConnect => 'No se pudo conectar. Inténtalo de nuevo.';

  @override
  String get shareNoDataReceived => 'No se recibieron datos';

  @override
  String get shareSearchRecords => 'Buscar registros';

  @override
  String get shareNoRecordsMatchFilters =>
      'No hay registros que coincidan con los filtros';

  @override
  String get shareNoRecordsAvailable => 'No hay registros disponibles';

  @override
  String get shareReceiverViewingRecords =>
      'El receptor está viendo los registros';

  @override
  String get shareSessionAutoExpire =>
      'La sesión expirará automáticamente cuando el temporizador llegue a cero';

  @override
  String get shareRecordsDelivered => 'Registros entregados con éxito';

  @override
  String get shareConnecting => 'Conectando...';

  @override
  String get shareConnectionInterrupted =>
      'Conexión interrumpida, reconectando';

  @override
  String get shareSendingRecords => 'Enviando registros...';

  @override
  String get shareReceivingRecords => 'Recibiendo registros...';

  @override
  String get shareConfirmExit => 'Confirmar salida';

  @override
  String get shareDeleteSharedRecords => '¿Eliminar registros compartidos?';

  @override
  String get shareDeleteWarning =>
      'El registro compartido se eliminará permanentemente de este dispositivo. La acción no se puede deshacer';

  @override
  String get shareDeleteAndExit => 'Eliminar y salir';

  @override
  String get shareIncomingTransfer => 'Transferencia entrante';

  @override
  String get shareViewOnlyWarning =>
      'Los registros serán de solo lectura y se eliminarán automáticamente al salir';

  @override
  String get shareDecline => 'Rechazar';

  @override
  String get shareAccept => 'Aceptar';

  @override
  String get shareSearchingForDevices => 'Buscando dispositivos cercanos...';

  @override
  String get shareSearchForDevices => 'Buscar dispositivos...';

  @override
  String get shareNoDevicesFound => 'No se encontraron dispositivos';

  @override
  String get shareConnectionIssue => 'Problema de conexión';

  @override
  String get shareWifiDirectUnresponsive =>
      'WiFi Direct no responde en este dispositivo.';

  @override
  String get shareWifiToggleHint =>
      'WiFi Direct no responde. Desactiva/activa WiFi, luego toca Reintentar.';

  @override
  String get shareDiscoveryHint =>
      'Asegúrate de que el otro dispositivo tenga la aplicación HealthWallet.me abierta';

  @override
  String get shareProximityHint =>
      'El dispositivo receptor debe tener Proximidad de compartir activada en Preferencias para ser detectable.';

  @override
  String get shareNoRecordsMatchSelectedFilters =>
      'No hay registros que coincidan con los filtros seleccionados';

  @override
  String get shareNoRecordsForAppliedFilters =>
      'No se encontraron registros para los filtros aplicados';

  @override
  String get shareTryClearingFilters => 'Intenta borrar algunos filtros';

  @override
  String get shareRecordsPageFiltersNoResults =>
      'Los filtros de la página de registros no devolvieron resultados';

  @override
  String get shareImportOrSyncRecords =>
      'Importa o sincroniza registros para compartirlos';

  @override
  String get shareSessionTime => 'Tiempo de sesión';

  @override
  String get shareSetAsDefault => 'Establecer como predeterminado';

  @override
  String get shareRecordsButton => 'Compartir registros';

  @override
  String get shareSelectRecordsToShare => 'Selecciona registros para compartir';

  @override
  String get shareEndSession => 'Finalizar sesión';

  @override
  String get shareRequestTenMin => 'Solicitar +10 min';

  @override
  String get shareWaitingForResponse => 'Esperando respuesta...';

  @override
  String get shareAddMoreTime => 'Agregar más tiempo';

  @override
  String get shareSessionExpiresIn => 'La sesión expira en';

  @override
  String get shareExtensionRequestedTitle => 'Extensión solicitada';

  @override
  String get shareHoursLabel => 'horas';

  @override
  String get shareMinLabel => 'min';

  @override
  String shareSelectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String shareRecordCount(int recordCount) {
    return '$recordCount registro(s)';
  }

  @override
  String shareSharedFrom(String source) {
    return 'compartido desde $source';
  }

  @override
  String shareFoundDevices(int count) {
    return 'Se encontraron $count dispositivo(s)';
  }

  @override
  String shareRetryingCount(int retryCount) {
    return 'Reintentando ($retryCount/3)...';
  }

  @override
  String shareDeviceWantsToShare(String deviceName) {
    return '$deviceName quiere compartir registros contigo';
  }

  @override
  String shareExtensionsUsed(int used, int max) {
    return '$used/$max extensiones usadas';
  }

  @override
  String shareDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h $minutes min';
  }

  @override
  String shareDurationHours(int hours) {
    return '${hours}h';
  }

  @override
  String shareDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String shareTimerHoursMinutesSeconds(int hours, int minutes, int seconds) {
    return '${hours}h ${minutes}min ${seconds}s';
  }

  @override
  String shareTimerMinutesSeconds(int minutes, int seconds) {
    return '${minutes}min ${seconds}s';
  }

  @override
  String shareTimerSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String shareMinuteCount(int minutes) {
    return '$minutes minuto(s)';
  }

  @override
  String shareSecondsCount(int seconds) {
    return '$seconds segundos';
  }

  @override
  String shareExtensionRequestMessage(String peerRole, String duration) {
    return 'El $peerRole quiere extender la sesión en $duration';
  }

  @override
  String get desktopSyncNotYet => 'Aún no';

  @override
  String get desktopSyncTransfer => 'Transferencia';

  @override
  String desktopSyncTransferValue(int sentRows, int receivedRows) {
    return '$sentRows enviados, $receivedRows recibidos';
  }

  @override
  String get desktopSyncPending => 'Pendiente';

  @override
  String desktopSyncPendingValue(int count) {
    return '$count cambios';
  }

  @override
  String desktopSyncingTable(String tableName) {
    return 'Sincronizando $tableName...';
  }

  @override
  String get desktopSyncing => 'Sincronizando...';

  @override
  String get desktopSyncNow => 'Sincronizar ahora';

  @override
  String get desktopSyncError => 'Error';

  @override
  String get desktopSyncInSync => 'Sincronizado';

  @override
  String get desktopSyncReady => 'Listo';

  @override
  String get desktopSyncOffline => 'Sin conexión';

  @override
  String get desktopTableHealthRecords => 'Registros de salud';

  @override
  String get desktopTableSources => 'Fuentes';

  @override
  String get desktopTableNotes => 'Notas';

  @override
  String get desktopTableSessions => 'Sesiones';

  @override
  String get desktopConnection => 'Conexión';

  @override
  String get desktopGeneratePairingQr => 'Generar QR de vinculación';

  @override
  String get desktopScanFromMobile => 'Escanea desde la página Sync del móvil';

  @override
  String get desktopDevice => 'Dispositivo';

  @override
  String get desktopTransport => 'Transporte';

  @override
  String get desktopIp => 'IP';

  @override
  String get desktopPort => 'Puerto';

  @override
  String get desktopNewPairing => 'Nueva vinculación';

  @override
  String get desktopTransportTcp => 'TCP sobre WiFi';

  @override
  String get desktopTransportMpc => 'MultipeerConnectivity (Directo)';

  @override
  String desktopConnectedTo(String name) {
    return 'Conectado a $name';
  }

  @override
  String get desktopConnected => 'Conectado';

  @override
  String desktopReconnectingTo(String name) {
    return 'Reconectando a $name...';
  }

  @override
  String get desktopReconnecting => 'Reconectando...';

  @override
  String desktopDisconnectedFrom(String name) {
    return 'Desconectado de $name';
  }

  @override
  String get desktopDisconnected => 'Desconectado';

  @override
  String get desktopDisconnect => 'Desconectar';

  @override
  String get desktopReconnect => 'Reconectar';

  @override
  String get desktopVpnDetected =>
      'VPN detectado. Desconecta la VPN para sincronizar con el escritorio.';

  @override
  String get desktopPairing => 'Vinculación';

  @override
  String get desktopLabel => 'Escritorio';

  @override
  String get desktopScanFromPhoneToPair =>
      'Escanea con tu teléfono para vincular';

  @override
  String get desktopNewQrCode => 'Nuevo código QR';

  @override
  String get desktopGenerateQrCode => 'Generar código QR';

  @override
  String get desktopScanQrCode => 'Escanear código QR';

  @override
  String get desktopChooseWhereToSave => 'Elige dónde guardar los respaldos';

  @override
  String get desktopSelectBackupFolder =>
      'Selecciona una carpeta en tu computadora para almacenar los respaldos';

  @override
  String get desktopChooseLocation => 'Elegir ubicación';

  @override
  String get desktopChooseBackupLocation => 'Elegir ubicación de respaldo';

  @override
  String get desktopBackingUp => 'Respaldando...';

  @override
  String get desktopCreateBackup => 'Crear respaldo';

  @override
  String get desktopSyncWithPhoneFirst => 'Sincroniza con el teléfono primero';

  @override
  String get desktopNotConnected => '(no conectado)';

  @override
  String get desktopStartBackup => 'Iniciar respaldo';

  @override
  String get desktopNoBackupsYet => 'Aún no hay respaldos';

  @override
  String get desktopCreateFirstBackup =>
      'Crea tu primer respaldo para mantener tus datos de salud seguros';

  @override
  String get desktopAllBackups => 'Todos los respaldos';

  @override
  String get desktopDate => 'Fecha';

  @override
  String get desktopSize => 'Tamaño';

  @override
  String get desktopChecksum => 'Suma de verificación';

  @override
  String get desktopRestoreThisBackup => 'Restaurar este respaldo';

  @override
  String get desktopRestoreBackupTitle => '¿Restaurar respaldo?';

  @override
  String desktopRestoreBackupMessage(String name, int count) {
    return 'Esto reemplazará todos los datos actuales en este dispositivo con \"$name\".\n\n Se restaurarán $count registros.\n\nTus datos en el teléfono vinculado no se verán afectados.';
  }

  @override
  String get desktopRestore => 'Restaurar';

  @override
  String get desktopDeleteBackupTitle => '¿Eliminar respaldo?';

  @override
  String desktopDeleteBackupMessage(String name) {
    return '¿Eliminar \"$name\"?\n\nEsto no se puede deshacer.';
  }

  @override
  String get desktopDelete => 'Eliminar';

  @override
  String get desktopBackupFrom => 'Respaldo del';

  @override
  String get desktopBackup => 'Respaldo';

  @override
  String get desktopChange => 'Cambiar';

  @override
  String get desktopProcessingHistory => 'Historial de procesamiento';

  @override
  String get desktopScannedOnPhone => 'Escaneado en el teléfono';

  @override
  String get desktopProcessedOnDesktop => 'Procesado en el escritorio';

  @override
  String get desktopImportedOnDesktop => 'Importado en el escritorio';

  @override
  String get desktopSyncRecent => 'Recientes';

  @override
  String get desktopUnknownDevice => 'Dispositivo desconocido';

  @override
  String desktopSyncHistoryTransfer(int sentRows, int receivedRows) {
    return '$sentRows enviados · $receivedRows recibidos';
  }

  @override
  String get desktopNewDeviceConnecting => 'Nuevo dispositivo conectándose';

  @override
  String desktopNewDeviceMessage(String address, String currentDevice) {
    return 'Un nuevo dispositivo ($address) quiere conectarse.\n\nEsto desconectará \"$currentDevice\".\n\n¿Cambiar al nuevo dispositivo?';
  }

  @override
  String get desktopKeepCurrent => 'Mantener actual';

  @override
  String get desktopSwitch => 'Cambiar';

  @override
  String get desktopCurrentDevice => 'dispositivo actual';

  @override
  String get desktopHandoverPreparing => 'Preparando...';

  @override
  String get desktopHandoverSendingFiles => 'Enviando archivos...';

  @override
  String get desktopHandoverProcessingOnDesktop =>
      'Procesando en el escritorio...';

  @override
  String get desktopHandoverComplete => '¡Completado!';

  @override
  String get desktopHandoverError => 'Ocurrió un error';

  @override
  String get desktopHandoverSending => 'Enviando...';

  @override
  String get desktopHandoverSendingToDesktop => 'Enviando al escritorio';

  @override
  String desktopHandoverFileCount(int count) {
    return '$count archivos';
  }

  @override
  String get desktopHandoverSuccess => 'Entregado al escritorio';

  @override
  String get desktopClose => 'Cerrar';

  @override
  String get desktopContinueImporting => 'Continuar importando';

  @override
  String get desktopHandoverToDesktop => 'Entregar al escritorio';

  @override
  String get desktopHandoverProcessingMessage =>
      'El procesamiento está en curso. La entrega cancelará el procesamiento actual y enviará los archivos al escritorio.';

  @override
  String get desktopHandover => 'Entrega';

  @override
  String get attachedDocuments => 'Documentos adjuntos';

  @override
  String get cameraPermissionRequired => 'Permiso de cámara requerido';

  @override
  String get cameraPermissionRequiredMessage =>
      'Esta app necesita acceso a la cámara para escanear. Por favor, otorga el permiso.';

  @override
  String get cameraPermissionDenied => 'Permiso de cámara denegado';

  @override
  String get cameraPermissionDeniedMessage =>
      'El permiso de cámara fue denegado permanentemente. Actívalo en Configuración para usar el escáner.';

  @override
  String get successTitle => '¡Éxito!';

  @override
  String attachmentSuccessMessage(int count) {
    return '$count documentos adjuntados exitosamente al encuentro.';
  }

  @override
  String get encounterLabel => 'Encuentro';

  @override
  String get viewRecords => 'Ver registros';

  @override
  String get errorTitle => 'Error';

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String get importDocument => 'Importar documento';

  @override
  String get pickImageFromGallery => 'Elegir imagen de la galería';

  @override
  String get scanDocument => 'Escanear documento';

  @override
  String get deleteSession => 'Eliminar sesión';

  @override
  String get deleteSessionConfirmation =>
      '¿Estás seguro de que quieres eliminar esta sesión?';

  @override
  String get delete => 'Eliminar';

  @override
  String get canceling => 'Cancelando...';

  @override
  String get waitingForAiToFinish => 'Esperando a que la IA termine...';

  @override
  String get logsCopied => 'Registros copiados';

  @override
  String get download => 'Descargar';

  @override
  String get active => 'Activo';

  @override
  String get tapToSelect => 'Toca para seleccionar';

  @override
  String deviceInfoChip(
    String platform,
    String ramGB,
    int cores,
    int estimatedMB,
  ) {
    return '$platform  •  $ramGB GB RAM  •  $cores núcleos  •  ~$estimatedMB MB necesarios';
  }

  @override
  String get downloadContinuesInBackground =>
      'Puedes navegar libremente, la descarga continuará en segundo plano.\nRevisa las notificaciones para ver el progreso.';

  @override
  String get continueWithoutAi =>
      'Continuar sin IA (descarga en segundo plano)';

  @override
  String get continueUsingApp => 'Seguir usando la app';

  @override
  String get attachWithoutProcessing =>
      'Quiero adjuntar el documento sin procesar';

  @override
  String get currentPatientAndSource => 'Paciente y fuente actuales';

  @override
  String get createEncounter => 'Crear encuentro';

  @override
  String get encounterName => 'Nombre del encuentro';

  @override
  String get enterEncounterName => 'Ingresa el nombre del encuentro';

  @override
  String get pleaseEnterEncounterName =>
      'Por favor, ingresa un nombre para el encuentro';

  @override
  String get date => 'Fecha';

  @override
  String get create => 'Crear';

  @override
  String get searchEncounters => 'Buscar encuentros...';

  @override
  String get noEncountersFound => 'No se encontraron encuentros';

  @override
  String get noEncountersFoundMessage =>
      'Crea un nuevo encuentro primero o selecciona un paciente diferente.';

  @override
  String get newEncounterPrefix => 'Nuevo encuentro';

  @override
  String get scannedDocumentsTitle => 'Documentos escaneados';

  @override
  String scannedDocumentsPagesTitle(String count) {
    return 'Documentos escaneados ($count páginas)';
  }

  @override
  String pdfFileTitle(String fileName) {
    return 'PDF: $fileName';
  }

  @override
  String get labelOrganizationName => 'Nombre de la organización';

  @override
  String get labelAddress => 'Dirección';

  @override
  String get labelPhone => 'Teléfono';

  @override
  String get labelEncounterName => 'Nombre del encuentro';

  @override
  String get labelStartDate => 'Fecha de inicio';

  @override
  String get labelFirstName => 'Nombre';

  @override
  String get labelFamilyName => 'Apellido';

  @override
  String get labelDateOfBirth => 'Fecha de nacimiento';

  @override
  String get labelGender => 'Género';

  @override
  String get labelReportName => 'Nombre del informe';

  @override
  String get labelConclusion => 'Conclusión';

  @override
  String get labelIssuedDate => 'Fecha de emisión';

  @override
  String get labelPractitionerName => 'Nombre del profesional';

  @override
  String get labelSpecialty => 'Especialidad';

  @override
  String get labelIdentifier => 'Identificador';

  @override
  String get labelConditionName => 'Nombre de la condición';

  @override
  String get labelOnsetDate => 'Fecha de inicio';

  @override
  String get labelClinicalStatus => 'Estado clínico';

  @override
  String get labelSubstance => 'Sustancia';

  @override
  String get labelManifestation => 'Manifestación';

  @override
  String get labelCategory => 'Categoría';

  @override
  String get labelProcedureName => 'Nombre del procedimiento';

  @override
  String get labelPerformedDate => 'Fecha de realización';

  @override
  String get labelReason => 'Motivo';

  @override
  String get labelMedicationName => 'Nombre del medicamento';

  @override
  String get labelDosage => 'Dosis';

  @override
  String get labelObservationName => 'Nombre de la observación';

  @override
  String get labelValue => 'Valor';

  @override
  String get labelUnit => 'Unidad';

  @override
  String get labelReferenceRange => 'Rango de referencia';

  @override
  String get permissionsRequired => 'Permisos requeridos';

  @override
  String recordsSelectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String get noRecordsSelected => 'No hay registros seleccionados';

  @override
  String get select => 'Seleccionar';

  @override
  String get selectRecordsBeforeSharing =>
      'Selecciona registros\nantes de compartir';

  @override
  String get selectRecordToViewDetails =>
      'Selecciona un registro para ver los detalles';

  @override
  String get recordDetails => 'Detalles del registro';

  @override
  String get viewDocument => 'Ver documento';

  @override
  String get encounterDetails => 'Detalles del encuentro';

  @override
  String get relatedResources => 'Recursos relacionados';

  @override
  String deletePlusRelated(int count) {
    return 'Eliminar + $count relacionados';
  }

  @override
  String get fileNotAvailable => 'Archivo no disponible en este dispositivo';

  @override
  String couldNotOpenFile(String message) {
    return 'No se pudo abrir el archivo: $message';
  }

  @override
  String errorOpeningFile(String error) {
    return 'Error al abrir el archivo: $error';
  }

  @override
  String get failedToLoadImage => 'No se pudo cargar la imagen';

  @override
  String errorLoadingPdf(String error) {
    return 'Error al cargar el PDF: $error';
  }

  @override
  String errorOnPage(String page, String error) {
    return 'Error en la página $page: $error';
  }

  @override
  String get notes => 'Notas';

  @override
  String get noNotesAttached => 'Este registro no tiene notas';

  @override
  String get addNote => 'Agregar nota';

  @override
  String get editNote => 'Editar nota';

  @override
  String get filters => 'Filtros';

  @override
  String get timeRange => 'Rango de tiempo';

  @override
  String get applyFilters => 'Aplicar filtros';

  @override
  String get recordType => 'Tipo de registro';

  @override
  String get specialty => 'Especialidad';

  @override
  String get allSpecialties => 'Todas las especialidades';

  @override
  String get selectedRange => 'Rango seleccionado';

  @override
  String get noRangeSelected => 'Sin rango seleccionado';

  @override
  String get clearDateRange => 'Limpiar rango de fechas';

  @override
  String get start => 'Inicio';

  @override
  String get end => 'Fin';

  @override
  String fromDate(String date) {
    return 'Desde $date';
  }

  @override
  String untilDate(String date) {
    return 'Hasta $date';
  }

  @override
  String get day => 'Día';

  @override
  String get month => 'Mes';

  @override
  String get year => 'Año';

  @override
  String get mediaInfo => 'Info de medios';

  @override
  String get linkToEncounter => 'Vincular a encuentro';

  @override
  String get noPdfDataAvailable => 'No hay datos PDF disponibles';

  @override
  String get failedToLoadPdf => 'No se pudo cargar el documento PDF';

  @override
  String get mediaInformation => 'Información de medios';

  @override
  String get mediaInfoTitle => 'Título:';

  @override
  String get mediaInfoType => 'Tipo:';

  @override
  String get mediaInfoStatus => 'Estado:';

  @override
  String get mediaInfoPatient => 'Paciente:';

  @override
  String get mediaInfoEncounter => 'Encuentro:';

  @override
  String get mediaInfoFileSize => 'Tamaño:';

  @override
  String get mediaInfoCreated => 'Creado:';

  @override
  String get mediaInfoResourceId => 'ID del recurso:';

  @override
  String get mediaInfoSource => 'Fuente:';

  @override
  String get close => 'Cerrar';

  @override
  String get linkMediaToEncounterDescription =>
      'Vincular este recurso multimedia a un encuentro:';

  @override
  String get encounterId => 'ID del encuentro';

  @override
  String get encounterIdHint => 'ej., encuentro-123';

  @override
  String get mediaLinkedSuccess =>
      'Recurso multimedia vinculado exitosamente al encuentro';

  @override
  String failedToLinkMedia(String error) {
    return 'Error al vincular: $error';
  }

  @override
  String get link => 'Vincular';

  @override
  String get connectionLabel => 'Conexión';

  @override
  String get connectionStatusConnected => 'Conectado';

  @override
  String get connectionStatusConnecting => 'Conectando...';

  @override
  String get connectionStatusDisconnected => 'Desconectado';

  @override
  String get connectionStatusNotPaired => 'No vinculado';

  @override
  String get syncLabel => 'Sincronización';

  @override
  String get syncStatusSyncing => 'Sincronizando...';

  @override
  String get syncStatusNotSynced => 'No sincronizado';

  @override
  String get syncStatusInSync => 'Sincronizado';

  @override
  String syncStatusPending(int count) {
    return '$count pendientes';
  }

  @override
  String get backupLabel => 'Respaldo';

  @override
  String get backupStatusWorking => 'Trabajando...';

  @override
  String get backupStatusNoBackup => 'Sin respaldo';

  @override
  String get backupStatusBackingUp => 'Respaldando...';

  @override
  String get backupStatusRestoring => 'Restaurando...';

  @override
  String get backupStatusWaiting => 'Esperando...';

  @override
  String get backupStatusNotConnected => 'No conectado';

  @override
  String get exportIpsPdf => 'Exportar IPS (PDF)';

  @override
  String get addIpsToAppleWallet => 'Agregar IPS a Apple Wallet';

  @override
  String get addIpsToGoogleWallet => 'Agregar IPS a Google Wallet';

  @override
  String get sourcesTitle => 'Fuentes';

  @override
  String get emergencyMedicalId => 'Identificación médica de emergencia';

  @override
  String get phoneLabel => 'Teléfono';

  @override
  String get allergiesLabel => 'Alergias';

  @override
  String get medicalConditionsLabel => 'Condiciones médicas';

  @override
  String get medicationsLabel => 'Medicamentos';

  @override
  String get conditionsLabel => 'Condiciones';

  @override
  String get dateOfBirthLabel => 'Fecha de nacimiento';

  @override
  String get emergencyPhoneLabel => 'Teléfono de emergencia';

  @override
  String get openingScanner => 'Abriendo escáner...';

  @override
  String get activeScanSessions => 'Sesiones de escaneo activas:';

  @override
  String get noScansYet => 'Aún no hay escaneos';

  @override
  String get scanOrImportToGetStarted =>
      'Escanea o importa documentos para comenzar';

  @override
  String pageOfTotal(String current, String total) {
    return '$current de $total';
  }

  @override
  String get fileNotFound => 'Archivo no encontrado';

  @override
  String get fileIsEmpty => 'El archivo está vacío';

  @override
  String get importTitle => 'Importar';

  @override
  String get activeImportSessions => 'Sesiones de importación activas:';

  @override
  String get dropToImport => 'Suelta para importar';

  @override
  String get dropFilesHereToImport => 'Suelta archivos aquí para importar';

  @override
  String get supportedFileFormats => 'PDF, JPG, PNG, TIFF';

  @override
  String get browseFiles => 'Explorar archivos';

  @override
  String get noImportsYet => 'Aún no hay importaciones';

  @override
  String get importOrScanToGetStarted =>
      'Importa o escanea documentos para comenzar';

  @override
  String get notificationsTitle => 'Notificaciones';

  @override
  String get noNotifications => 'Sin notificaciones';

  @override
  String get cancelDownloadTitle => 'Cancelar descarga';

  @override
  String get cancelDownloadMessage =>
      '¿Estás seguro de que quieres cancelar la descarga del modelo de IA? Puedes reiniciarla más tarde.';

  @override
  String get processingDone => 'Procesamiento completado';

  @override
  String pairedWithDevice(String deviceName) {
    return 'Vinculado con $deviceName';
  }

  @override
  String get deviceSyncLabel => 'Sincronización de dispositivo';

  @override
  String get disconnectLabel => 'Desconectar';

  @override
  String get changeLabel => 'Cambiar';

  @override
  String get minimizeToTray => 'Minimizar a la bandeja';

  @override
  String get changeSpecialty => 'Cambiar especialidad';

  @override
  String get changeSpecialtyConfirm =>
      '¿Seguro que quieres cambiar la especialidad a';

  @override
  String get removeSpecialtyConfirm =>
      '¿Seguro que quieres quitar la especialidad de este registro?';

  @override
  String get confirm => 'Confirmar';

  @override
  String get currentRecord => 'Registro actual';

  @override
  String get vitalHeartRate => 'Frecuencia cardíaca';

  @override
  String get vitalBloodPressure => 'Presión arterial';

  @override
  String get vitalTemperature => 'Temperatura';

  @override
  String get vitalBloodOxygen => 'Oxígeno en sangre';

  @override
  String get vitalRespiratoryRate => 'Frecuencia respiratoria';

  @override
  String get vitalWeight => 'Peso';

  @override
  String get vitalHeight => 'Altura';

  @override
  String get vitalBmi => 'IMC';

  @override
  String get vitalBloodGlucose => 'Glucosa en sangre';

  @override
  String get vitalSystolicBloodPressure => 'Presión arterial sistólica';

  @override
  String get vitalDiastolicBloodPressure => 'Presión arterial diastólica';

  @override
  String get specialtyAllergology => 'Alergología';

  @override
  String get specialtyCardiology => 'Cardiología';

  @override
  String get specialtyDental => 'Odontología';

  @override
  String get specialtyDermatology => 'Dermatología';

  @override
  String get specialtyEmergencyMedicine => 'Medicina de urgencias';

  @override
  String get specialtyEndocrinology => 'Endocrinología';

  @override
  String get specialtyGastroenterology => 'Gastroenterología';

  @override
  String get specialtyGeneralCare => 'Medicina general';

  @override
  String get specialtyGynecology => 'Ginecología';

  @override
  String get specialtyNephrology => 'Nefrología';

  @override
  String get specialtyNeurology => 'Neurología';

  @override
  String get specialtyOncology => 'Oncología';

  @override
  String get specialtyOphthalmology => 'Oftalmología';

  @override
  String get specialtyOrthopedics => 'Ortopedia';

  @override
  String get specialtyPsychiatry => 'Psiquiatría';

  @override
  String get specialtyPulmonology => 'Neumología';

  @override
  String get specialtyRheumatology => 'Reumatología';

  @override
  String get specialtyUrology => 'Urología';

  @override
  String get categoryAllergies => 'Alergias';

  @override
  String get categoryCareTeam => 'Equipo de atención';

  @override
  String get categoryClinicalNotes => 'Notas clínicas';

  @override
  String get categoryFiles => 'Archivos';

  @override
  String get categoryLabResults => 'Resultados de laboratorio';

  @override
  String get categoryHealthIssues => 'Problemas de salud';

  @override
  String get categoryFacilities => 'Centros médicos';

  @override
  String get categoryHealthGoals => 'Objetivos de salud';

  @override
  String get categoryImmunizations => 'Vacunas';

  @override
  String get categoryMedications => 'Medicamentos';

  @override
  String get categoryDemographics => 'Datos personales';

  @override
  String get categoryProcedures => 'Procedimientos';

  @override
  String get categoryHealthInsurance => 'Seguro médico';

  @override
  String get fhirTypeAdverseEvent => 'Evento adverso';

  @override
  String get fhirTypeAllergyIntolerance => 'Alergia';

  @override
  String get fhirTypeBinary => 'Archivo binario';

  @override
  String get fhirTypeCareTeam => 'Equipo de atención';

  @override
  String get fhirTypeClaim => 'Reclamación';

  @override
  String get fhirTypeCondition => 'Condición';

  @override
  String get fhirTypeCoverage => 'Cobertura';

  @override
  String get fhirTypeDiagnosticReport => 'Informe diagnóstico';

  @override
  String get fhirTypeDocumentReference => 'Documento';

  @override
  String get fhirTypeEncounter => 'Encuentro';

  @override
  String get fhirTypeExplanationOfBenefit => 'Explicación de beneficios';

  @override
  String get fhirTypeGoal => 'Objetivo';

  @override
  String get fhirTypeImmunization => 'Vacuna';

  @override
  String get fhirTypeLocation => 'Ubicación';

  @override
  String get fhirTypeMedia => 'Multimedia';

  @override
  String get fhirTypeMedication => 'Medicamento';

  @override
  String get fhirTypeMedicationAdministration =>
      'Administración de medicamento';

  @override
  String get fhirTypeMedicationDispense => 'Dispensación de medicamento';

  @override
  String get fhirTypeMedicationRequest => 'Prescripción de medicamento';

  @override
  String get fhirTypeMedicationStatement => 'Declaración de medicación';

  @override
  String get fhirTypeObservation => 'Observación';

  @override
  String get fhirTypeOrganization => 'Organización';

  @override
  String get fhirTypePatient => 'Paciente';

  @override
  String get fhirTypePractitioner => 'Profesional';

  @override
  String get fhirTypePractitionerRole => 'Rol del profesional';

  @override
  String get fhirTypeProcedure => 'Procedimiento';

  @override
  String get fhirTypeRelatedPerson => 'Persona relacionada';

  @override
  String get fhirTypeServiceRequest => 'Solicitud de servicio';

  @override
  String get fhirTypeSpecimen => 'Muestra';

  @override
  String get fhirTypeGeneralResource => 'Recurso';

  @override
  String get processingOriginScan => 'Escaneo';

  @override
  String get processingOriginImport => 'Importación';

  @override
  String get processingOriginHandover => 'Entrega';

  @override
  String get processingStatusPending => 'Pendiente';

  @override
  String get processingStatusProcessingPatient => 'Procesando paciente';

  @override
  String get processingStatusPatientExtracted => 'Paciente extraído';

  @override
  String get processingStatusProcessing => 'Procesando';

  @override
  String get processingStatusDraft => 'Borrador';

  @override
  String get processingStatusCancelled => 'Cancelado';

  @override
  String get showAll => 'Mostrar todo';

  @override
  String get showLess => 'Mostrar menos';

  @override
  String get all => 'Todos';

  @override
  String get gotIt => 'Entendido';

  @override
  String get homeSpecialties => 'Especialidades';

  @override
  String get homeResources => 'Recursos';

  @override
  String get homeDefaultUserName => 'Usuario';

  @override
  String get selectSpecialty => 'Seleccionar especialidad';

  @override
  String get removeSpecialty => 'Quitar especialidad';

  @override
  String get chooseRecordsForDashboard =>
      'Elige los registros que quieres ver en tu panel.';

  @override
  String get selectAtLeastOneRecordType =>
      'Selecciona al menos un tipo de registro para continuar.';

  @override
  String get chooseVitalsForDashboard =>
      'Elige los signos vitales que quieres ver en tu panel.';

  @override
  String get selectAtLeastOneVital =>
      'Selecciona al menos un signo vital para continuar.';

  @override
  String get chooseSpecialtiesForDashboard =>
      'Elige las especialidades que quieres ver en tu panel.';

  @override
  String get selectAtLeastOneSpecialty =>
      'Selecciona al menos una especialidad para continuar.';

  @override
  String get selectAtLeastOneItem =>
      'Selecciona al menos un elemento para continuar.';

  @override
  String get sourceSectionWallet => 'WALLET';

  @override
  String get sourceSectionEhr => 'FUENTES DE HCE';

  @override
  String get areYouSure => '¿Estás seguro?';

  @override
  String get resourceNotViewable =>
      'Este recurso no es un archivo visualizable';

  @override
  String get noFilePathFound => 'No se encontró la ruta del archivo';

  @override
  String get handoverPatientMatched => 'Paciente de la entrega asociado';

  @override
  String get desktopFinishedProcessing =>
      'El escritorio terminó el procesamiento';

  @override
  String get biometricAuthReason =>
      'Autentícate para acceder a tu HealthWallet.me';

  @override
  String sourceUploadedOn(String date) {
    return 'Subido $date';
  }

  @override
  String couldNotOpenPdf(String message) {
    return 'No se pudo abrir el PDF: $message';
  }

  @override
  String errorOpeningPdf(String error) {
    return 'Error al abrir el PDF: $error';
  }

  @override
  String get shareStatusReadyToShare => 'Listo para compartir';

  @override
  String get shareStatusWaitingForSender => 'Esperando al remitente...';

  @override
  String get shareStatusPermissionsRequired => 'Se requieren permisos';

  @override
  String get shareStatusEnablePermissionsInSettings =>
      'Activa los permisos en Configuración';

  @override
  String get shareSelectAtLeastOneRecord => 'Selecciona al menos un registro';

  @override
  String get shareStatusLookingForDevices =>
      'Buscando dispositivos cercanos...';

  @override
  String get shareStatusTransferFailed => 'La transferencia falló';

  @override
  String get shareStatusConfirmExit =>
      '¿Seguro que quieres salir? Los datos se eliminarán.';

  @override
  String shareStatusViewingRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Viendo $count registros',
      one: 'Viendo 1 registro',
    );
    return '$_temp0';
  }

  @override
  String shareStatusViewingRecordsFrom(int count, String deviceName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Viendo $count registros de $deviceName',
      one: 'Viendo 1 registro de $deviceName',
    );
    return '$_temp0';
  }

  @override
  String get shareStatusDataDeleted =>
      'Los datos se han eliminado de forma segura';

  @override
  String get shareStatusSessionExpired => 'La sesión ha caducado';

  @override
  String get shareStatusTerminatingSession => 'Finalizando la sesión remota...';

  @override
  String get shareStatusSessionTerminated => 'Sesión finalizada';

  @override
  String get shareStatusRemoteSessionTerminated =>
      'El otro dispositivo finalizó la sesión';

  @override
  String get shareStatusExtensionDeclined =>
      'Se rechazó la solicitud de extensión';

  @override
  String get shareStatusReceiverViewing =>
      'El receptor está viendo los registros - supervisando la sesión';

  @override
  String get shareStatusReceiverDeclined => 'El receptor rechazó la invitación';

  @override
  String shareStatusReceivingFrom(String deviceName) {
    return 'Recibiendo registros de $deviceName...';
  }

  @override
  String get shareNoDataAvailable => 'No hay datos disponibles';

  @override
  String shareStatusDeviceWantsToShare(String deviceName) {
    return '$deviceName quiere compartir registros';
  }

  @override
  String get shareStatusScanning => 'Buscando dispositivos...';

  @override
  String shareStatusFoundDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se encontraron $count dispositivos',
      one: 'Se encontró 1 dispositivo',
    );
    return '$_temp0';
  }

  @override
  String shareStatusConnectingTo(String deviceName) {
    return 'Conectando con $deviceName...';
  }

  @override
  String get shareStatusPreparingRecords => 'Preparando registros...';

  @override
  String get shareErrorPrepareFiles =>
      'No se pudieron preparar los archivos para el envío';

  @override
  String shareStatusTransferring(int percent) {
    return 'Transfiriendo $percent %';
  }

  @override
  String get shareStatusRecordsSentWaiting =>
      'Registros enviados - esperando a que el receptor acepte';

  @override
  String get shareStatusTransferCancelled => 'Transferencia cancelada';

  @override
  String get shareStatusInvitationRejected => 'Invitación rechazada';

  @override
  String get shareErrorParseData => 'No se pudieron leer los datos recibidos';

  @override
  String get shareStatusProcessingReceived =>
      'Procesando los registros recibidos...';

  @override
  String get shareErrorParseFile => 'No se pudo leer el archivo recibido';

  @override
  String get shareIncomingHealthRecords => 'Registros de salud entrantes';

  @override
  String shareDeviceWantsToShareHealthRecords(String deviceName) {
    return '$deviceName quiere compartir registros de salud contigo';
  }

  @override
  String get sharePermissionExplanationIos =>
      'Para compartir registros con dispositivos cercanos, HealthWallet necesita acceso a:\n\n• Bluetooth - para encontrar dispositivos cercanos y conectarse a ellos\n\nAsí puedes compartir registros de salud de forma segura con otros dispositivos cercanos.';

  @override
  String get sharePermissionExplanationAndroid =>
      'Para compartir registros con dispositivos cercanos, HealthWallet necesita acceso a:\n\n• Bluetooth - para encontrar dispositivos cercanos y conectarse a ellos\n• Ubicación/Dispositivos cercanos - Android lo exige para buscar dispositivos Bluetooth y WiFi Direct\n\nTu ubicación nunca se guarda ni se transmite.';

  @override
  String get sharePermissionsDeniedMessage =>
      'Concede todos los permisos para compartir registros con dispositivos cercanos.';

  @override
  String get sharePermissionsPermanentlyDeniedMessage =>
      'Se denegaron algunos permisos. Actívalos en Configuración para usar esta función.';

  @override
  String shareDurationRequested(String duration) {
    return '$duration solicitados';
  }

  @override
  String get noAttachments => 'Sin archivos adjuntos';

  @override
  String get attachingFiles => 'Adjuntando archivos...';

  @override
  String get addAttachment => 'Añadir archivo adjunto';

  @override
  String get noFileName => 'Sin nombre de archivo';

  @override
  String attachmentFileOfTotal(int current, int total) {
    return '( $current de $total archivos )';
  }

  @override
  String get showDetails => 'Ver detalles';

  @override
  String get viewRelated => 'Ver relacionados';

  @override
  String get hideRelated => 'Ocultar relacionados';

  @override
  String get noRelatedResourcesFound =>
      'No se encontraron recursos relacionados';

  @override
  String get loadingRelatedResources => 'Cargando recursos relacionados...';

  @override
  String get noRelatedResourcesForEncounter =>
      'No se encontraron recursos relacionados con este encuentro';

  @override
  String get cannotAttachToDocumentReference =>
      'No se pueden adjuntar archivos a un documento';

  @override
  String deleteRecordOfType(String type) {
    return 'Eliminar $type';
  }

  @override
  String get dateFilterEndBeforeStart =>
      'La fecha de fin debe ser posterior a la fecha de inicio';

  @override
  String dateFilterChip(String range) {
    return 'Fecha: $range';
  }

  @override
  String get aiModelCheckFailed =>
      'Se produjo un error al comprobar si el modelo existe';

  @override
  String get aiModelExistenceCheckFailed =>
      'No se pudo comprobar si el modelo existe';

  @override
  String aiModelDownloadingTitle(String modelName) {
    return 'Descargando $modelName';
  }

  @override
  String get aiModelDownloadStarting => 'Iniciando la descarga...';

  @override
  String aiModelReadyTitle(String modelName) {
    return '$modelName listo';
  }

  @override
  String aiModelDownloadedMessage(String modelName) {
    return '$modelName se ha descargado correctamente.';
  }

  @override
  String get aiModelDownloadFailedTitle => 'Error en la descarga';

  @override
  String get aiModelDownloadFailedMessage =>
      'No se pudo descargar el modelo de IA. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get aiModelDownloadFailed => 'La descarga ha fallado';

  @override
  String get aiModelDownloadCancelledTitle => 'Descarga cancelada';

  @override
  String get aiModelDownloadInterruptedMessage =>
      'La descarga se interrumpió. Inténtalo de nuevo.';

  @override
  String get aiModelDownloadCancelledNotificationTitle =>
      'Descarga del modelo de IA cancelada';

  @override
  String get aiModelDownloadWasCancelled =>
      'Se canceló la descarga del modelo de IA';

  @override
  String get aiModelDownloadCancelled => 'Descarga cancelada';

  @override
  String aiModelDownloadingPercent(String percent) {
    return 'Descargando... $percent %';
  }

  @override
  String get processingNoImagesGenerated =>
      'No se generaron imágenes del escaneo. Vuelve a escanear.';

  @override
  String processingPatientMatched(String origin) {
    return '$origin: paciente asociado';
  }

  @override
  String processingPatientInfoExtracted(String origin) {
    return '$origin: datos del paciente extraídos';
  }

  @override
  String processingFinished(String origin) {
    return '$origin: procesamiento finalizado';
  }

  @override
  String scanFailedWithError(String error) {
    return 'Error al escanear: $error';
  }

  @override
  String get noValidFilesFound => 'No se encontraron archivos válidos';

  @override
  String failedToImportDocument(String error) {
    return 'No se pudo importar el documento: $error';
  }

  @override
  String get couldNotOpenLink =>
      'No se pudo abrir el enlace. Inténtalo de nuevo.';

  @override
  String get continueProcessingOnDesktop =>
      'Continuar el procesamiento en el escritorio';

  @override
  String get deleteResourcesTitle => 'Eliminar recursos';

  @override
  String get switchToDiagnosticReport => 'Cambiar a informe diagnóstico';

  @override
  String get switchToEncounter => 'Cambiar a encuentro';

  @override
  String get previewDocument => 'Vista previa del documento';

  @override
  String get summaryTitle => 'Resumen';

  @override
  String pagesAvailableForProcessing(int count) {
    return 'Total: $count páginas disponibles para procesar';
  }

  @override
  String get betaBadge => 'Beta';

  @override
  String get pleaseSelectSpecialty => 'Selecciona una especialidad';

  @override
  String get patientAndSourceInformation =>
      'Información del paciente y de la fuente';

  @override
  String get noPatientsAvailable => 'No hay pacientes disponibles';

  @override
  String get selectPatient => 'Seleccionar paciente';

  @override
  String get unknownPatient => 'Paciente desconocido';

  @override
  String get documentPreview => 'Vista previa del documento';

  @override
  String filePathLabel(String path) {
    return 'Ruta: $path';
  }

  @override
  String get confidenceMedium => 'Confianza media';

  @override
  String get confidenceLow => 'Confianza baja';

  @override
  String get dateFormatHintIso => 'AAAA-MM-DD';

  @override
  String retryStep(int step) {
    return 'Reintentar (paso $step)';
  }

  @override
  String failedToCreateEncounter(String error) {
    return 'No se pudo crear el encuentro: $error';
  }

  @override
  String failedToAttachDocuments(String error) {
    return 'No se pudieron adjuntar los documentos: $error';
  }
}
