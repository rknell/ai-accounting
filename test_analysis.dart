import 'package:dart_openai_client/dart_openai_client.dart';

void main() {
  // This is just to test if the import works by touching the ApiClient symbol
  final apiTypeReference = ApiClient;
  // ignore: avoid_print
  print('Testing import with symbol: $apiTypeReference');
}
