import 'package:flutter/material.dart';

class GroupSeenScreen extends StatelessWidget {
  final List<String> userNames;

  const GroupSeenScreen({Key? key, required this.userNames}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Seen By")),
      body: ListView.separated(
        itemCount: userNames.length,
        separatorBuilder: (_, __) => Divider(height: 0),
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(userNames[index]),
            leading: const Icon(Icons.visibility, color: Colors.green),
          );
        },
      ),
    );
  }
}
