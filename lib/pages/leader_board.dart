import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardScreen extends StatefulWidget {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<UserRanking> userList = [];
  UserRanking? currentUserRanking;
  int currentUserRank = -1;
  bool isWeeklySelected = true; // true for Weekly, false for Monthly


  @override
  void initState() {
    super.initState();
    fetchUsersAndSortByWins();
  }


  Widget _buildToggleButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10), // Adjust the space between toggle button and other sections
      height: 40, // Adjust the height of the toggle button
      decoration: BoxDecoration(
        color: Colors.blue, // Base color for unselected state
        borderRadius: BorderRadius.circular(20), // Rounded corners for the toggle button
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // To keep the toggle button compact
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                isWeeklySelected = true;
                fetchUsersAndSortByWins();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: isWeeklySelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Text(
                'Weekly',
                style: TextStyle(
                  color: isWeeklySelected ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                isWeeklySelected = false;
                fetchUsersAndSortByWins();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: !isWeeklySelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Text(
                'All Time',
                style: TextStyle(
                  color: !isWeeklySelected ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  void fetchUsersAndSortByWins() async {
    FirebaseFirestore.instance.collection('users').get().then((snapshot) {
      List<UserRanking> users = snapshot.docs.map((doc) {
        return UserRanking(
          userId: doc.id,
          userName: doc.data()['name'] ?? 'Unknown',
          avatarUrl: doc.data()['avatar'],
          wins: doc.data()['wins'] ?? 0,
          weeklyWins: doc.data()['weeklyWins'] ?? 0,
        );
      }).toList();

      // Sort users by wins
      users.sort((a, b) => b.wins.compareTo(a.wins));

      // Determine rank and find current user
      for (var i = 0; i < users.length; i++) {
        if (users[i].userId == widget.currentUserId) {
          currentUserRanking = users[i];
          currentUserRank = i + 1; // Ranking starts at 1
          break;
        }
      }

      if (isWeeklySelected) {
        users.sort((a, b) => b.weeklyWins.compareTo(a.weeklyWins));
      } else {
        users.sort((a, b) => b.wins.compareTo(a.wins));
      }


      setState(() {
        userList = users;
      });
    });
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Text('Leaderboard'),
  //     ),
  //     body: Column(
  //       children: [
  //         if (currentUserRanking != null)
  //           Padding(
  //             padding: const EdgeInsets.all(8.0),
  //             child: Container(
  //               padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
  //               decoration: BoxDecoration(
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Text('#$currentUserRank', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
  //                   CircleAvatar(
  //                     radius: 30, // Increase the avatar size
  //                     backgroundImage: currentUserRanking!.avatarUrl != null ? NetworkImage(currentUserRanking!.avatarUrl!) : null,
  //                     child: currentUserRanking!.avatarUrl == null ? Text(currentUserRanking!.userName[0], style: TextStyle(fontSize: 24)) : null,
  //                   ),
  //                   Expanded(
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.center,
  //                       children: [
  //                         Text(currentUserRanking!.userName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
  //                       ],
  //                     ),
  //                   ),
  //                   // Adjusted part: Display wins or weeklyWins based on isWeeklySelected
  //                   Text('${isWeeklySelected ? "Weekly Wins: " : "Wins: "}${isWeeklySelected ? currentUserRanking!.weeklyWins : currentUserRanking!.wins}', style: TextStyle(fontSize: 24, color: Colors.black)),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         _buildToggleButton(),
  //         SizedBox(height: 10), // Provide spacing between current user and list
  //         Expanded(
  //           child: ListView.builder(
  //             itemCount: userList.length,
  //             itemBuilder: (context, index) {
  //               UserRanking user = userList[index];
  //               return Container(
  //                 margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
  //                 padding: const EdgeInsets.all(8.0),
  //                 decoration: BoxDecoration(
  //                   color: Colors.white, // Use a different background color for contrast
  //                   border: Border.all(color: Colors.grey),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     Text('#${index + 1}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold) ),
  //                     SizedBox(width: 8),
  //                     CircleAvatar(
  //                       backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
  //                       child: user.avatarUrl == null ? Text(user.userName[0]) : null,
  //                     ),
  //                     Expanded(
  //                       child: Text(user.userName, style: TextStyle(fontSize: 16)),
  //                     ),
  //                     // Text('Wins: ${user.wins}', style: TextStyle(fontSize: 16)),
  //                     Text('${isWeeklySelected ? "Weekly Wins: " : "Wins: "}${isWeeklySelected ? user.weeklyWins : user.wins}', style: TextStyle(fontSize: 16)),
  //                   ],
  //                 ),
  //               );
  //             },
  //           ),
  //         ),
  //
  //       ],
  //     ),
  //   );
  // }







  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      // Wrap your main Column in a Padding widget
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 200.0), // Adjust the horizontal padding as needed
        child: Column(
          children: [
            if (currentUserRanking != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('#$currentUserRank', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      CircleAvatar(
                        radius: 30, // Increase the avatar size
                        backgroundImage: currentUserRanking!.avatarUrl != null ? NetworkImage(currentUserRanking!.avatarUrl!) : null,
                        child: currentUserRanking!.avatarUrl == null ? Text(currentUserRanking!.userName[0], style: TextStyle(fontSize: 24)) : null,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(currentUserRanking!.userName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                          ],
                        ),
                      ),
                      Text('${isWeeklySelected ? "Weekly Wins: " : "Wins: "}${isWeeklySelected ? currentUserRanking!.weeklyWins : currentUserRanking!.wins}', style: TextStyle(fontSize: 24, color: Colors.black)),
                    ],
                  ),
                ),
              ),

            _buildToggleButton(),

            SizedBox(height: 15), // Provide spacing between current user and list
            Expanded(
              child: ListView.builder(
                itemCount: userList.length,
                itemBuilder: (context, index) {
                  UserRanking user = userList[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white, // Use a different background color for contrast
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('#${index + 1}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        CircleAvatar(
                          backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                          child: user.avatarUrl == null ? Text(user.userName[0]) : null,
                        ),
                        Expanded(
                          child: Text(user.userName, style: TextStyle(fontSize: 16)),
                        ),
                        Text('${isWeeklySelected ? "Weekly Wins: " : "Wins: "}${isWeeklySelected ? user.weeklyWins : user.wins}', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }





}




class UserRanking {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final int wins;
  final int weeklyWins;

  UserRanking({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.wins,
    required this.weeklyWins,
  });
}
