import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

Future<void> uploadFileToBackend(String filePath) async {
  final uri = Uri.parse("http://192.168.1.71:5000/upload"); // Use your machine IP

  var request = http.MultipartRequest("POST", uri);
  request.files.add(await http.MultipartFile.fromPath("file", filePath));

  var response = await request.send();
  if (response.statusCode == 200) {
    print("File uploaded successfully!");
  } else {
    print("Upload failed: ${response.statusCode}");
  }
}
