import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_init.dart';

class FaqItem {
  final String id;
  final String questionEn;
  final String questionGu;
  final String answerEn;
  final String answerGu;
  final int priority;

  FaqItem({
    required this.id,
    required this.questionEn,
    required this.questionGu,
    required this.answerEn,
    required this.answerGu,
    required this.priority,
  });

  factory FaqItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FaqItem(
      id: doc.id,
      questionEn: data['questionEn'] ?? '',
      questionGu: data['questionGu'] ?? '',
      answerEn: data['answerEn'] ?? '',
      answerGu: data['answerGu'] ?? '',
      priority: data['priority'] ?? 0,
    );
  }
}

class FaqProvider with ChangeNotifier {
  List<FaqItem> _faqs = [];
  bool _isLoading = true;

  List<FaqItem> get faqs => _faqs;
  bool get isLoading => _isLoading;

  FaqProvider() {
    _listenToFaqs();
  }

  void _listenToFaqs() async {
    await FirebaseInit.initialize();
    FirebaseFirestore.instance
        .collection('faqs')
        .orderBy('priority', descending: true)
        .snapshots()
        .listen((snapshot) {
      _faqs = snapshot.docs.map((doc) => FaqItem.fromFirestore(doc)).toList();
      _isLoading = false;
      notifyListeners();
    });
  }
}
