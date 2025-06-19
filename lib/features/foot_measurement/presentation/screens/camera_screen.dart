import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'results_screen.dart';
import '../../../../core/services/opencv_service.dart';
import '../../data/models/foot_measurement.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  double _qrSizeCm = 3.0; // Taille par défaut du QR en cm
  bool _useQRMode = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeOpenCV();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    await _controller.initialize();
    setState(() => _isCameraInitialized = true);
  }

  Future<void> _initializeOpenCV() async {
    final success = await OpenCVService.initialize();
    if (!success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur d\'initialisation OpenCV'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcess() async {
    setState(() => _isProcessing = true);

    try {
      print('📸 Capture de l\'image...');
      final image = await _controller.takePicture();
      final imageBytes = await image.readAsBytes();
      print('✅ Image capturée: ${imageBytes.length} bytes');

      if (_useQRMode && OpenCVService.isQRFunctionsAvailable) {
        // Mode QR: traitement complet avec calibration
        print('🎯 Mode QR activé');
        final result = await OpenCVService.processFootWithQR(
          imageBytes, 
          qrSizeCm: _qrSizeCm
        );

        if (result == null) {
          _showErrorAndFallback('Échec du traitement avec QR', imageBytes);
          return;
        }

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(
              originalImage: imageBytes,
              processedImage: result.processedImageBytes,
              measurement: result.measurement,
            ),
          ),
        );
      } else {
        // Mode fallback: ancien système
        print('⚠️ Mode fallback (sans QR)');
        final processedBytes = await OpenCVService.removeBackground(imageBytes);
        
        if (processedBytes == null) {
          _showError('Échec du traitement de l\'image');
          return;
        }

        // Extraction des mesures avec le nouveau système
        final measurement = await OpenCVService.extractFootMeasurements(
          imageBytes, 
          qrSizeCm: _qrSizeCm
        );

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(
              originalImage: imageBytes,
              processedImage: processedBytes,
              measurement: measurement,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur capture et traitement: $e');
      _showError('Erreur lors du traitement: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorAndFallback(String message, Uint8List imageBytes) async {
    _showError(message);
    
    // Tentative de fallback
    print('🔄 Tentative de fallback...');
    final processedBytes = await OpenCVService.removeBackground(imageBytes);
    final measurement = await OpenCVService.extractFootMeasurements(imageBytes);
    
    if (processedBytes != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            originalImage: imageBytes,
            processedImage: processedBytes,
            measurement: measurement,
          ),
        ),
      );
    }
  }

  void _showQRSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Taille du QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sélectionnez la taille de votre QR code de référence:'),
            const SizedBox(height: 16),
            DropdownButton<double>(
              value: _qrSizeCm,
              items: const [
                DropdownMenuItem(value: 2.0, child: Text('2.0 cm')),
                DropdownMenuItem(value: 2.5, child: Text('2.5 cm')),
                DropdownMenuItem(value: 3.0, child: Text('3.0 cm (défaut)')),
                DropdownMenuItem(value: 4.0, child: Text('4.0 cm')),
                DropdownMenuItem(value: 5.0, child: Text('5.0 cm')),
              ],
              onChanged: (value) {
                setState(() {
                  _qrSizeCm = value ?? 3.0;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isCameraInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                // Prévisualisation de la caméra
                CameraPreview(_controller),
                
                // Overlay avec instructions
                Positioned(
                  top: 60,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              _useQRMode ? Icons.qr_code : Icons.warning,
                              color: _useQRMode ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _useQRMode 
                                  ? 'Mode QR: Placez un QR code (${_qrSizeCm}cm) dans l\'image'
                                  : 'Mode estimation: Mesures moins précises',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!OpenCVService.isQRFunctionsAvailable)
                          const Text(
                            'Fonctions QR non disponibles - Mode compatibilité',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),

                // Cadre de guidage
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    height: MediaQuery.of(context).size.height * 0.65,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessing ? Colors.orange : Colors.blue,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _isProcessing
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 16),
                                Text(
                                  'Traitement en cours...',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),

                // Boutons de contrôle
                Positioned(
                  bottom: 40,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Bouton réglages QR
                      if (OpenCVService.isQRFunctionsAvailable)
                        FloatingActionButton(
                          heroTag: "qr_settings",
                          mini: true,
                          backgroundColor: Colors.white.withOpacity(0.9),
                          onPressed: _showQRSizeDialog,
                          child: const Icon(Icons.settings, color: Colors.black),
                        ),

                      // Bouton capture principal
                      FloatingActionButton.extended(
                        heroTag: "capture",
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        onPressed: _isProcessing ? null : _captureAndProcess,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt),
                        label: Text(_isProcessing ? "Traitement..." : "Scanner le pied"),
                      ),

                      // Toggle mode QR/Estimation
                      if (OpenCVService.isQRFunctionsAvailable)
                        FloatingActionButton(
                          heroTag: "toggle_mode",
                          mini: true,
                          backgroundColor: _useQRMode 
                              ? Colors.green.withOpacity(0.9)
                              : Colors.orange.withOpacity(0.9),
                          onPressed: () {
                            setState(() {
                              _useQRMode = !_useQRMode;
                            });
                          },
                          child: Icon(
                            _useQRMode ? Icons.qr_code : Icons.straighten,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),

                // Indicateur de statut en bas
                Positioned(
                  bottom: 120,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      OpenCVService.isInitialized
                          ? 'OpenCV prêt • ${OpenCVService.isQRFunctionsAvailable ? "QR disponible" : "QR indisponible"}'
                          : 'Initialisation OpenCV...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OpenCVService.isInitialized ? Colors.green : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Initialisation de la caméra...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
    );
  }
}