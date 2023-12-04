import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MessageScreen extends StatefulWidget {
  final String opponentUId;

  MessageScreen({Key? key, required this.opponentUId}) : super(key: key);

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  late final Stream<List<DocumentSnapshot>> _messagesStream;
  String myUserId = '';
  late String chatId;

  @override
  void initState() {
    super.initState();
    myUserId = FirebaseAuth.instance.currentUser!.uid;
    chatId = getChatId(myUserId, widget.opponentUId) as String; // Implement this method to determine the chatId

    _messagesStream = FirebaseFirestore.instance.collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
    snapshot.docs); // This gives you a stream of message documents
  }

  String getChatId(String user1, String user2) {
    // Combine the two user IDs in a consistent order to generate a chatId
    var sortedIds = [user1, user2]..sort();
    return sortedIds.join('_'); // Join the sorted list into a single string
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Message'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _messagesStream,
              builder:(context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                List<DocumentSnapshot> messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var messageData = messages[index].data() as Map<String, dynamic>;
                    bool isOwnMessage = messageData['fromId'] == myUserId;
                    return Align(
                      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                        margin: EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                        decoration: BoxDecoration(
                          color: isOwnMessage ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: isOwnMessage
                              ? const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                              bottomLeft: Radius.circular(12))
                              : const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12)),
                        ),
                        child: Text(
                          messageData['text'],
                          style: TextStyle(fontSize: 16.0),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.message),
                labelText: 'Say hi',
                labelStyle: TextStyle(
                  color: Colors.black.withOpacity(0.3), // Adjust the opacity value as needed
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    sendMessage(_messageController.text);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) {
                sendMessage(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  void sendMessage(String message) {
    if (message.trim().isNotEmpty) {
      FirebaseFirestore.instance.collection('chats')
          .doc(chatId)
          .collection('messages').add({
        'text': message,
        'fromId': myUserId,
        'toId': widget.opponentUId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update the userChats collection
      FirebaseFirestore.instance.collection('userChats').doc(myUserId).set({
        chatId: {
          'lastMessage': message,
          'timestamp': FieldValue.serverTimestamp(),
          // 'unreadCount' should be managed via Cloud Functions or another mechanism
        }
      }, SetOptions(merge: true));

      FirebaseFirestore.instance.collection('userChats').doc(widget.opponentUId).set({
        chatId: {
          'lastMessage': message,
          'timestamp': FieldValue.serverTimestamp(),
          // 'unreadCount' should be managed via Cloud Functions or another mechanism
        }
      }, SetOptions(merge: true));

      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
