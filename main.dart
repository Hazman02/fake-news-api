import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io'; // for File
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(MyApp());
}

// Sender enum
enum Sender { user, system }

// Simple message model
class Message {
  final Sender sender;
  final String content;
  Message({required this.sender, required this.content});
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fake News Detector (Dark Chat Style)',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Color(0xFF1A1A1A),
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white,
        ),
      ),
      home: ChatLikeFakeNewsScreen(),
    );
  }
}

class ChatLikeFakeNewsScreen extends StatefulWidget {
  @override
  _ChatLikeFakeNewsScreenState createState() => _ChatLikeFakeNewsScreenState();
}

class _ChatLikeFakeNewsScreenState extends State<ChatLikeFakeNewsScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  bool _isLoading = false;

  // For text headlines
  Future<void> _predictFakeNews(String headline) async {
    // Immediately show the user's input as a bubble
    setState(() {
      _messages.add(
        Message(sender: Sender.user, content: headline),
      );
      _isLoading = true;
    });

    try {
      var url = Uri.parse('http://10.0.2.2:8000/predict'); // or your server
      var response = await http.post(url, body: {'headline': headline});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Build a multi-line reply
        String displayText =
            "Headline: ${data["headline"]}\n\n"
            "Prediction: ${data["prediction"]}\n\n"
            "Fake Probability: ${data["fake_probability"]}\n\n"
            "Real Probability: ${data["real_probability"]}";

        setState(() {
          _messages.add(
            Message(sender: Sender.system, content: displayText),
          );
        });
      } else {
        setState(() {
          _messages.add(
            Message(
              sender: Sender.system,
              content: "Error: ${response.statusCode}",
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          Message(sender: Sender.system, content: 'Exception: $e'),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // For images
  Future<void> _pickImageAndPredict() async {
    try {
      // Use image_picker to get an image from gallery
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return; // user canceled

      // Show a bubble for the user's "action"
      setState(() {
        _messages.add(
          Message(sender: Sender.user, content: "[User selected an image]"),
        );
        _isLoading = true;
      });

      // Send multipart to /predict_from_image_api
      var url = Uri.parse('http://10.0.2.2:8000/predict_from_image_api');
      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Build a multi-line text from the server’s JSON
        String displayText =
            "Extracted Text: ${data["extracted_text"]}\n\n"
            "Prediction: ${data["prediction"]}\n\n"
            "Fake Probability: ${data["fake_probability"]}\n\n"
            "Real Probability: ${data["real_probability"]}";

        setState(() {
          _messages.add(
            Message(sender: Sender.system, content: displayText),
          );
        });
      } else {
        setState(() {
          _messages.add(
            Message(sender: Sender.system, content: "Error: ${response.statusCode}"),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          Message(sender: Sender.system, content: 'Exception: $e'),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSendPressed() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _predictFakeNews(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fake News Detector (Chat Style)'),
      ),
      body: Column(
        children: [
          // The chat bubbles
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return ChatBubble(message: msg);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          SafeArea(
            child: Container(
              color: Color(0xFF2A2A2A),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter your headline...',
                        hintStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onSubmitted: (_) => _onSendPressed(),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Predict button (for text)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _onSendPressed,
                    child: Text('Predict'),
                  ),
                  SizedBox(width: 8),
                  // Upload Image button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _pickImageAndPredict,
                    child: Icon(Icons.image),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Chat bubble widget with partial bold logic
class ChatBubble extends StatelessWidget {
  final Message message;
  const ChatBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == Sender.user;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isUser ? Colors.blueGrey[700] : Colors.grey[800];

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.all(12),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(isUser ? 12 : 0),
              bottomRight: Radius.circular(isUser ? 0 : 12),
            ),
          ),
          child: _buildMessageContent(message.content, isUser),
        ),
      ],
    );
  }

  // This method will bold certain keywords and justify text
  Widget _buildMessageContent(String content, bool isUser) {
    // Justify the text
    if (isUser) {
      return Text(
        content,
        textAlign: TextAlign.justify,
        style: TextStyle(color: Colors.white),
      );
    } else {
      // We'll bold known lines like "Headline:", "Prediction:", etc.
      final lines = content.split('\n');
      List<InlineSpan> spans = [];

      for (var line in lines) {
        if (line.startsWith("Headline:") ||
            line.startsWith("Extracted Text:") ||
            line.startsWith("Prediction:") ||
            line.startsWith("Fake Probability:") ||
            line.startsWith("Real Probability:")) {
          final colonIndex = line.indexOf(":");
          if (colonIndex != -1) {
            final label = line.substring(0, colonIndex + 1); // e.g. "Headline:"
            final value = line.substring(colonIndex + 1).trim();

            spans.add(
              TextSpan(
                text: label + " ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            );
            spans.add(
              TextSpan(
                text: value + "\n",
                style: TextStyle(color: Colors.white),
              ),
            );
          } else {
            spans.add(TextSpan(
              text: line + "\n",
              style: TextStyle(color: Colors.white),
            ));
          }
        } else {
          // Normal line
          spans.add(TextSpan(
            text: line + "\n",
            style: TextStyle(color: Colors.white),
          ));
        }
      }

      return RichText(
        textAlign: TextAlign.justify,
        text: TextSpan(children: spans),
      );
    }
  }
}
