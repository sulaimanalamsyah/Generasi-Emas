import 'package:flutter/material.dart';
import '../../routes.dart';

class FolderNursePage extends StatelessWidget {
  const FolderNursePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Folder Perawat')),
      body: ListView(children: [
        ListTile(leading: const Icon(Icons.lightbulb), title: const Text('Brainstorming Perawat'), onTap: ()=>Navigator.pushNamed(context, Routes.nurseBrainstorm)),
        ListTile(leading: const Icon(Icons.inventory), title: const Text('Pasien Binaan'), onTap: ()=>Navigator.pushNamed(context, Routes.nurseAgg)),
        ListTile(leading: const Icon(Icons.quiz), title: const Text('Quiz Perawat'), onTap: ()=>Navigator.pushNamed(context, Routes.nurseQuiz)),
      ]),
    );
  }
}
