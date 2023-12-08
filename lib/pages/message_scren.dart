import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
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
    chatId = getChatId(myUserId, widget.opponentUId);

    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);

    resetUnreadCount();
  }

  void resetUnreadCount() {
    if (chatId.isNotEmpty) {
      FirebaseFirestore.instance.collection('userChats').doc(widget.opponentUId).set({
        chatId: {'unreadCount': 0},
      }, SetOptions(merge: true));
    }
  }



  String getChatId(String user1, String user2) {
    var sortedIds = [user1, user2]..sort();
    return sortedIds.join('_');
  }

  Future<int> getCurrentUserBalance(String userId) async {
    var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists && userDoc.data() is Map<String, dynamic>) {
      return (userDoc.data() as Map<String, dynamic>)['chessCoins'] ?? 0;
    }
    return 0;
  }

  void showGiftModal(BuildContext context) async {
    String myUserId = FirebaseAuth.instance.currentUser!.uid;
    int myCurrentBalance = await getCurrentUserBalance(myUserId);
    int? selectedAmount;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Align(
                    alignment: Alignment.topRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Balance: $myCurrentBalance ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        CircleAvatar(
                          backgroundImage: AssetImage('assets/NBC-token.png'),
                          radius: 10,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    children: [25, 50, 100].map((amount) {
                      return GestureDetector(
                        onTap: () => setState(() => selectedAmount = amount),
                        child: Container(
                          margin: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedAmount == amount ? Colors.brown : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: selectedAmount == amount ? Colors.black : Colors.white),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                backgroundImage: AssetImage('assets/NBC-token.png'),
                                radius: 30,
                              ),
                              Text(
                                "$amount",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selectedAmount == amount ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    child: const Text("Send Gift"),
                    onPressed: (selectedAmount != null && selectedAmount! <= myCurrentBalance)
                        ? () {
                      handleGift(widget.opponentUId, selectedAmount!, myUserId, myCurrentBalance);
                      Navigator.of(context).pop();
                    }
                        : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void handleGift(String recipientUserId, int amount, String myUserId, int myCurrentBalance) async {
    if (amount > myCurrentBalance) {
      return; // Optionally, show an error message indicating insufficient balance
    }

    DocumentReference myUserRef = FirebaseFirestore.instance.collection('users').doc(myUserId);
    DocumentReference recipientUserRef = FirebaseFirestore.instance.collection('users').doc(recipientUserId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot recipientSnapshot = await transaction.get(recipientUserRef);
      int recipientCurrentBalance = (recipientSnapshot.data() as Map<String, dynamic>)['chessCoins'] ?? 0;

      transaction.update(myUserRef, {'chessCoins': myCurrentBalance - amount});
      transaction.update(recipientUserRef, {'chessCoins': recipientCurrentBalance + amount});

      String message = "$amount";
      sendMessageToRecipient(recipientUserId, message, isGiftMessage: true);
    });
  }

  void sendMessageToRecipient(String recipientUserId, String message, {bool isGiftMessage = false}) {
    var messageRef = FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').doc();
    messageRef.set({
      'text': message,
      'fromId': myUserId,
      'toId': recipientUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'isGiftMessage': isGiftMessage,
    });

    FirebaseFirestore.instance.collection('userChats').doc(myUserId).set({
      chatId: {
        'unreadCount': FieldValue.increment(1),
      }
    }, SetOptions(merge: true));
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
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                    bool isGiftMessage = messageData['isGiftMessage'] ?? false;

                    return Align(
                      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                        margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                        decoration: BoxDecoration(
                          color: isOwnMessage ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: isGiftMessage
                            ? buildGiftMessage(messageData['text'], isOwnMessage)
                            : buildTextMessage(messageData['text']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 50,
                  child: IconButton(
                    icon: const Icon(
                      CupertinoIcons.gift,
                      size: 38,
                    ),
                    onPressed: () => showGiftModal(context),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 45, // Adjust the height as needed
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: 'Say hi',
                        labelStyle: TextStyle(
                          color: Colors.black.withOpacity(0.3),
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
                ),
                IconButton(
                  icon: const Icon(
                    Icons.send,
                    size: 40,
                    color: Colors.green,
                  ),
                  onPressed: () {
                    sendMessage(_messageController.text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGiftMessage(String amount, bool isSender){
    return Container(
      padding: EdgeInsets.all(8), // Add padding inside the container
      width: 150, // Adjust the width as needed
      height: 150, // Adjust the height as needed
      decoration: BoxDecoration(
        color: Colors.white, // Change color as needed
        borderRadius: BorderRadius.circular(8),

      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            isSender ? 'Sent' : 'Received',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 5), // Spacing between text and image
          const CircleAvatar(
            backgroundImage: AssetImage('assets/NBC-token.png'),
            radius: 20, // Adjust the radius as needed
          ),
          const SizedBox(height: 5), // Spacing between image and amount
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }


  Widget buildTextMessage(String message) {
    return Text(
      message,
      style: const TextStyle(fontSize: 16.0),
    );
  }


  void sendMessage(String message, {bool isGiftMessage = false}) {
    if (message.trim().isNotEmpty) {
      var messageRef = FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').doc();
      messageRef.set({
        'text': message,
        'fromId': myUserId,
        'toId': widget.opponentUId,
        'timestamp': FieldValue.serverTimestamp(),
        'isGiftMessage': isGiftMessage,
      });

      // Create or update chat document
      FirebaseFirestore.instance.collection('userChats').doc(myUserId).set({
        chatId: {
          'unreadCount': FieldValue.increment(1),
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
