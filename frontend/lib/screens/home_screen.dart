import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/analysis_provider.dart';
import '../widgets/result_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final provider = Provider.of<AnalysisProvider>(context, listen: false);
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: source);

    if (pickedFile != null) {
      provider.setImage(File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Image Analyzer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              Provider.of<AnalysisProvider>(context, listen: false).clear();
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Consumer<AnalysisProvider>(
              builder: (context, provider, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (provider.image != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        height: 250,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: Image.file(
                            provider.image!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    if (provider.image == null)
                      ElevatedButton.icon(
                        onPressed: () => _showImageSourceDialog(context),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Image'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (provider.image != null && !provider.isLoading)
                      ElevatedButton.icon(
                        onPressed: () {
                          provider.analyzeImage().then((_) {
                            if (provider.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(provider.errorMessage!),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          });
                        },
                        icon: const Icon(Icons.analytics),
                        label: const Text('Analyze Image'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    if (provider.isLoading)
                      const CircularProgressIndicator(),
                    if (provider.analysisResult != null)
                      ResultCard(analysis: provider.analysisResult!),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
