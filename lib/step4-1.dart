import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:form_app/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';

class Step4_1 extends StatefulWidget {
  final List<String> invoiceIds;

  Step4_1({required this.invoiceIds});

  @override
  _Step4_1State createState() => _Step4_1State();
}

class _Step4_1State extends State<Step4_1> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  Set<String> selectedInvoiceIds = {};
  bool isUploading = false;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _image = image;
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) {
      Get.snackbar('Error', 'Please select an image first');
      return;
    }

    if (selectedInvoiceIds.isEmpty) {
      Get.snackbar('Error', 'Please select at least one invoice');
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      final firebaseService = ApiService();
      final imageFile = File(_image!.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final fileName =
          'acknowledgement_${DateTime.now().millisecondsSinceEpoch}.jpg';

      var result = await firebaseService.uploadImage(
          selectedInvoiceIds.toList(), fileName, imageBytes);
      if (!result) {
        print("INSIDE ERROR");
        throw Exception('Failed to upload image');
      }

      Get.snackbar('Success', 'Image uploaded successfully');
      Get.offAllNamed('/');
      // Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Failed to upload image');
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('Upload Acknowledgement'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Invoices:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return widget.invoiceIds;
                }
                return widget.invoiceIds.where((String invoiceId) {
                  return invoiceId
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()) &&
                      !selectedInvoiceIds.contains(invoiceId);
                });
              },
              displayStringForOption: (String option) => 'Invoice #$option',
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Select Invoice Numbers',
                    border: OutlineInputBorder(),
                  ),
                );
              },
              onSelected: (String selection) {
                setState(() {
                  selectedInvoiceIds.add(selection);
                });
              },
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: selectedInvoiceIds.map((invoiceId) {
                return Chip(
                  label: Text('Invoice #$invoiceId'),
                  deleteIcon: Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      selectedInvoiceIds.remove(invoiceId);
                    });
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            if (_image != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.file(File(_image!.path), fit: BoxFit.cover),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Select Photo'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: (isUploading || !AuthService.to.perms.canUpdate(ScreenKeys.step4)) ? null : _uploadImage,
              child: isUploading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Upload'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
