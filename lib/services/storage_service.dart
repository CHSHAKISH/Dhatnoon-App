import 'dart.io'; // Make sure to import 'dart:io' for the 'File' type
import 'package.firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadTicketMedia(String ticketId, File file) async {
    try {
      // Create a reference path
      String filePath = 'ticket_media/$ticketId/sample.jpg';

      // Upload the file
      UploadTask uploadTask = _storage.ref().child(filePath).putFile(file);

      // Wait for the upload to complete
      TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;

    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }
}