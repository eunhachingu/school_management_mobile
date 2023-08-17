import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:school_management/models/student/student.dart';
import 'package:school_management/models/student/subject.dart';
import 'package:school_management/services/networks/auth/auth.dart';
import 'package:http/http.dart' as http;
import 'package:school_management/values/strings/api/key.dart';

class StudentDB extends ChangeNotifier {
  
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  
  final FirebaseFirestore db = FirebaseFirestore.instance;

  bool isLoading = false;

  void showHUD(bool value) {
    isLoading = value;
    notifyListeners();
  }

  /// [studentStream] will get the info of the student
  Stream<List<StudentModel>>? listOfStudentsStream;

  Stream<List<StudentModel>> getListOfStudentsStream() {

    return db.collection("students")
        .snapshots()
        .map(_listOfStudentsFromSnapshots);
  }

  List<StudentModel> _listOfStudentsFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return StudentModel.fromJson(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  void updateListOfStudentsStream() {
    listOfStudentsStream = getListOfStudentsStream();
    notifyListeners();
  }

  /// [studentStream] will get the info of the student
  Stream<StudentModel>? studentStream;
  
  Stream<StudentModel> getUserInfo(BuildContext context) {
    final Auth auth = Provider.of<Auth>(context, listen: false);

    return db.collection(auth.author!)
      .doc(firebaseAuth.currentUser!.uid)
      .snapshots().map(_studentFromSnapshots);
  }

  StudentModel _studentFromSnapshots(DocumentSnapshot snapshot) {
    return StudentModel.fromJson(snapshot.data() as Map<String, dynamic>);
  }

  void updateStudentModel(BuildContext context) {
    studentStream = getUserInfo(context);
    notifyListeners();
  }

  /// [subjectStream] will generate the subjects of
  /// the student current log in
  Stream<List<SubjectModel>>? subjectStream;

  Stream<List<SubjectModel>> getSubject(BuildContext context) {
    final Auth auth = Provider.of<Auth>(context, listen: false);

    final subjectStream = db.collection(auth.author!)
        .doc(firebaseAuth.currentUser!.uid)
        .collection("subjects")
        .snapshots()
        .map(_subjectFromSnapshots);
    return subjectStream;
  }

  List<SubjectModel> _subjectFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((QueryDocumentSnapshot doc) {
      return SubjectModel.fromJson(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  void updateSubjectStream(BuildContext context) {
    subjectStream = getSubject(context);
    notifyListeners();
  }
  

  SubjectModel get stemGrades {
    Map<String, dynamic> practicalResearch1 = {
      "title": "Practical Research 1",
      "grade": 100,
      "id": "1232131",
      "semester": 1,
      "strand": "stem",
      "year": "11",
      "instructor": {
        "name": "erwin",
        "id": "1232132"
      }
    };

    return SubjectModel.fromJson(practicalResearch1);
  }

  Future<void> uploadGrades() async {

    await db.collection("students")
        .doc(firebaseAuth.currentUser!.uid)
        .collection("subjects")
        .add(stemGrades.toJson()).then((value) {
          print("Generated subjects!");
    });
  }

  Future<Map<String, dynamic>> createPayment() async {
    try {
      Map<String, dynamic> body = {
        "amount": "1000",
        "currency": "USD",
      };

      http.Response response = await http.post(
        Uri.parse("https://api.stripe.com/v1/payment_intents"),
        body: body,
        headers: {
          "Authorization": "Bearer ${ApiKey.stripeSecretKey}",
          "Content-Type": "application/x-www-form-urlencoded"
        }
      ).then((http.Response response) {

        if (response.body.isNotEmpty && response.statusCode == 200) {
          debugPrint(response.body);
          return response;

        } else {
          return response;
        }

      });


      return json.decode(response.body);
    } catch (e) {
      throw Exception(e.toString());
    }
  }


  Future<void> displayPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
      print("Done");
    } catch (e) {
      print("Failed");
    }
  }

  Map<String, dynamic>? paymentIntent;

  Future<void> makePayment() async {
    try {
      paymentIntent = await createPayment();

      const gPay = PaymentSheetGooglePay(
        merchantCountryCode: "US",
        currencyCode: "USD",
        testEnv: true,
      );

      notifyListeners();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent!["client_secret"] as String,
          style: ThemeMode.dark,
          merchantDisplayName: "Choi",
          googlePay: gPay,
        )).then((value) {
          displayPaymentSheet();
      });

    } catch (e) {
      throw "Error: ${e}";
    }
  }

}