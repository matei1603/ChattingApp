import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/crypto_service.dart';
import '../screens/image_viewer_page.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final String currentUserId;

  const MessageBubble({
    Key? key,
    required this.data,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = data['senderId'] == currentUserId;
    final visibilityEmoji = {
      'public': '🌍',
      'home': '🏠',
      'work': '💼',
    };
    final visibility = data['visibility'] ?? 'public';

    final encryptedText = isCurrentUser
        ? data['messageForSender']
        : data['messageForReceiver'];
    final encryptedImageUrl = isCurrentUser
        ? data['imageUrlForSender']
        : data['imageUrlForReceiver'];
    final encryptedDocumentUrl = isCurrentUser
        ? data['documentUrlForSender']
        : data['documentUrlForReceiver'];

    return FutureBuilder<Map<String, String>>(
      future: _decryptMessage(encryptedText, encryptedImageUrl, encryptedDocumentUrl),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final decrypted = snapshot.data!;
        final text = decrypted['text'] ?? '';
        final imageUrl = decrypted['imageUrl'] ?? '';
        final documentUrl = decrypted['documentUrl'] ?? '';

        return Column(
          crossAxisAlignment:
          isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrentUser ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl.startsWith('http'))
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ImageViewerPage(imageUrl: imageUrl),
                          ),
                        );
                      },
                      child: Image.network(imageUrl, height: 200),
                    ),
                  if (text.isNotEmpty && text != '[Decryption Failed]')
                    Text(
                      text,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black,
                      ),
                    ),
                  if (documentUrl.startsWith('http'))
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(documentUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open document')),
                          );
                        }
                      },
                      child: Text(
                        '📄 Open Document',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: isCurrentUser ? Colors.white : Colors.blueAccent,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  Text(
                    visibilityEmoji[visibility] ?? '',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, String>> _decryptMessage(String? text, String? imageUrl, String? documentUrl) async {
    final result = <String, String>{};

    try {
      result['text'] = (text != null && text.isNotEmpty)
          ? await CryptoService.decryptText(text)
          : '';
    } catch (_) {
      result['text'] = '[Decryption Failed]';
    }

    try {
      result['imageUrl'] = (imageUrl != null && imageUrl.isNotEmpty)
          ? await CryptoService.decryptText(imageUrl)
          : '';
    } catch (_) {
      result['imageUrl'] = '';
    }

    try {
      result['documentUrl'] = (documentUrl != null && documentUrl.isNotEmpty)
          ? await CryptoService.decryptText(documentUrl)
          : '';
    } catch (_) {
      result['documentUrl'] = '';
    }

    return result;
  }
}
