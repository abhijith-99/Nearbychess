import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';

class LeaderboardScreen extends StatefulWidget {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {


  List<UserRanking> userList = [];
  UserRanking? currentUserRanking;
  int currentUserRank = -1;

  int currentWeeklyRank = -1;
  bool isWeeklySelected = true;


  List<UserRanking> weeklyUserList = [];
  List<UserRanking> allTimeUserList = [];

  @override
  void initState() {
    super.initState();
    fetchUsersAndSortByWins();
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



      List<UserRanking> sortedWeekly = List<UserRanking>.from(users);
      sortedWeekly.sort((a, b) => b.weeklyWins.compareTo(a.weeklyWins));

      // Sort for all-time wins
      List<UserRanking> sortedAllTime = List<UserRanking>.from(users);
      sortedAllTime.sort((a, b) => b.wins.compareTo(a.wins));

      setState(() {
        weeklyUserList = sortedWeekly;
        allTimeUserList = sortedAllTime;

        // Assuming currentUserRanking should be based on all-time wins
        currentUserRanking = users.where((user) => user.userId == widget.currentUserId).isNotEmpty
            ? users.firstWhere((user) => user.userId == widget.currentUserId)
            : null;

        currentUserRank = currentUserRanking != null ? users.indexWhere((user) => user.userId == widget.currentUserId) + 1 : -1;

        int currentWeeklyRank = currentUserRanking != null ? sortedWeekly.indexWhere((user) => user.userId == widget.currentUserId) + 1 : -1;

        // Assuming you have a state variable to hold currentWeeklyRank; otherwise, declare one
        this.currentWeeklyRank = currentWeeklyRank;

      });
    });
  }









  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard',  textAlign: TextAlign.center,
          style: TextStyle(
            // Add any additional styles here if needed
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      // Wrap your main Column in a Padding widget
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0), // Adjust the horizontal padding as needed
        child: Column(
          children: [
            if (currentUserRanking != null)
              Padding(
                padding: const EdgeInsets.all(13.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('#$currentUserRank', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      CircleAvatar(
                        radius: 40, // Increase the avatar size
                        backgroundImage: currentUserRanking!.avatarUrl != null ? NetworkImage(currentUserRanking!.avatarUrl!) : null,
                        child: currentUserRanking!.avatarUrl == null ? Text(currentUserRanking!.userName[0], style: TextStyle(fontSize: 20)) : null,
                      ),
                      // Using Spacer to ensure the name and wins are pushed to opposite ends
                      // Spacer(),
                      Expanded(
                        flex: 2, // Adjust the flex to give more room to the name if needed
                        child: Text(currentUserRanking!.userName, textAlign: TextAlign.start, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                      Spacer(flex: 1,), // Another Spacer to maintain the centering of the username

                    ],
                  ),
                ),
              ),


            SizedBox(height: 30), // Provide spacing between current user and list

            SizedBox(
              height: 60, // Adjust height as necessary
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Weekly Wins', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                      if (currentUserRanking != null) // Check if currentUserRanking is not null
                        Row(
                          children: [
                            SvgPicture.asset('assets/ranking-star-solid.svg', width: 20, color: Colors.black), // Adjust size as needed
                            const SizedBox(width: 10), // Provide some spacing between the icon and the text
                            Text(
                              '$currentWeeklyRank',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(width: 20), // Spacing between rank and wins
                            Image.asset('assets/trophy-solid.png', width: 20, color: Colors.black), // Adjust size as needed
                            Text(
                              '${currentUserRanking!.weeklyWins}',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('All Time Wins', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                      if (currentUserRanking != null) // Check if currentUserRanking is not null
                        Row(
                          children: [
                            SvgPicture.asset('assets/ranking-star-solid.svg', width: 20, color: Colors.black), // Rank icon
                            const SizedBox(width: 10), // Provide some spacing
                            Text(
                              '$currentUserRank',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(width: 20), // Spacing between rank and wins
                            Image.asset('assets/trophy-solid.png', width: 20, color: Colors.black), // Wins icon
                            Text(
                              '${currentUserRanking!.wins}',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),




            Expanded(
              child: Row(
                children: [
                  // Weekly Wins Column
                  Expanded(
                    child: ListView.builder(
                      itemCount: weeklyUserList.length,
                      itemBuilder: (context, index) {
                        return buildUserListItem(weeklyUserList[index], index + 1, true);
                      },
                    ),
                  ),


                  const SizedBox(width: 15),
                  // All Time Wins Column
                  Expanded(
                    child: ListView.builder(
                      // itemCount: userList.length,
                      itemCount: allTimeUserList.length,
                      itemBuilder: (context, index) {
                        // return buildUserListItem(userList[index], false); // false for all-time
                        return buildUserListItem(allTimeUserList[index], index + 1, false);
                      },
                    ),
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget buildUserListItem(UserRanking user, int rank, bool isWeeklyList) {
    return Container(
      margin: const EdgeInsets.all(4.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        // color: Colors.white,
        color: user.userId == widget.currentUserId ? Colors.blue[100] : Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('#$rank', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          CircleAvatar(backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null),
          Expanded(child: Text(user.userName, style: const TextStyle(fontSize: 16))),

          Row(
            children: [
              Image.asset(
                'assets/trophy-solid.png', // Path to your SVG file
                width: 10, // Adjust the size as needed
                height: 10,
                color: Colors.black, // Adjust the color as needed
              ),
              const SizedBox(width: 7),
              Text(
                '${isWeeklyList ? user.weeklyWins : user.wins}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),

        ],
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


