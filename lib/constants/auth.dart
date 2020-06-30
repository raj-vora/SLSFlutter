import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chirp_flutter/chirp_flutter.dart';
import 'dart:typed_data';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

abstract class BaseAuth {
  //FIREBASE FUNCTIONS
  Future<String> signInWithEmailAndPassword(String email, String password);
  Future<String> createUserWithEmailAndPassword(String email, String password);
  Future<String> currentUser();
  Future<String> getEmailId();
  Future<void> resetPassword(String _emailId);
  Future<void> signOut();
  Future<void> deleteUser();
  
  //FORM VALIDATION FUNCTION
  bool validateAndSave(formKey);
  
  //CHIRP FUNCTIONS
  Future<void> requestPermissions();
  Future<void> initChirp();
  Uint8List createChirp(String _userId, String _userSecret, String mode);
  Future<void> sendChirp(Uint8List _chirpData);
  
  //REGISTRATION FUNCTION
  Future<List> initRegistration();
  List createUserId();
  void registerUser(String _userId, Map<String, String> json);
  void registerHome(String _userId, String _userSecret, String _homeId, String _homeName, Uint8List _chirpData, String _deviceToken);
  Future<bool> registerCheck(String _homeId, String _userId);
  
  //BOTTOM TOAST
  void createToast(String message);
  
  //HASHING FUNCTION
  String hashSecret (String _userSecret);
  Future<String> getPrimaryUser(String homeId);
  void sendMail(String primaryEmail, String userId, String otp);
  void otpVerified(String homeId);
}

class Auth implements BaseAuth{
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final db = Firestore.instance;
  FirebaseUser user;

  //FIREBASE FUNCTIONS
  Future<String> signInWithEmailAndPassword(String email, String password) async {
    try {
    user = (await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password)).user;
    }on PlatformException{
      createToast('User does\'t exist');
    }
    return user.uid;
  }

  Future<String> createUserWithEmailAndPassword(String email, String password) async {
    try {
    user = (await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password)).user;
    } on PlatformException{
      createToast('User already registered, please sign in');
    }
    return user.uid;
  }

  Future<String> currentUser() async {
    user = await _firebaseAuth.currentUser();
    return user != null ? user.uid : null;
  }

  Future<String> getEmailId() async {
    user = await _firebaseAuth.currentUser();
    return user.email;
  }

  Future<void> resetPassword(String _emailId) async {
    await _firebaseAuth.sendPasswordResetEmail(email: _emailId);
  }

  Future<void> signOut() async {
    return _firebaseAuth.signOut();
  }

  Future<void> deleteUser() async {
    user = await _firebaseAuth.currentUser();
    print('User to be deleted $user');
    db.collection('users').getDocuments().then((snapshot){
      snapshot.documents.forEach((f) => {
        if(f['authId']==user){
          f.reference.delete()
        }
      });
    });
    await user.delete().then((value) => {
      print('User Deleted')
    });
  }

  //CHIRP FUNCTIONS
  Future<void> requestPermissions() async {
    PermissionStatus permission = await PermissionHandler().checkPermissionStatus(PermissionGroup.microphone);
    if (permission.toString() != 'granted') {
      await PermissionHandler().requestPermissions([PermissionGroup.microphone]);
    }
  }

  Future<void> initChirp() async {
    String _appKey = 'a7cbAC032bad0FBbCA0bAE528';
    String _appSecret = 'ac0E3e41c3AfFBE3CED431e5CE4Eee8aC1e793BF353a42bd7E';
    String _appConfig = 'aTEFRnJLaqzx7nF0U9nb4+SLAjabUC3wBgvMu+0K9LOgGneO16xBh/9WxlkwVf3IRX9mtM1e1aLStrd4jHCFpTm6RLMsAU/bTf4OzxhB8trz0UXvjO2kRIXPuUiaLrc5I1Ekm1wpgtVW3S+dy3SPoe1/eWo9kj6JWUNfNZZdcgKwxhyeI/j9NBNTxp/NFdtFSjQRpuDjxZkw1Ttf/cBDDY0X3FlaG+7j3/OaPa/plVtAMe7Enxjt2CQ6Eg10pzei1tP7RoK/A88EH8RDHmEBCklZGMLmU8RsE08Wv3wEywbc5jG06Edc+KudW19xo7Ab/h2ZHcohkVMjbuO5QkmiH2fGaXNR/0rsKc26q/L740Zsfrw2BoI3mhYEWvYQaHz4LQoD+OrtYvtcasuAlpkjYrlhUo/wUrB4TdLOkPLX4JImmaJZGqmGrHS0NBP9GEhj4c3M3qTEX4MZuU/ai/tWGZEs/grtqbwbOKi0fWwroBUJp1Ba2Edh50KnhcoT2jw3OF6yCZSWPotD9ui/OIbNkdvU2M+ZU7X4+wXtP2IGGz57xCRpNjjeYoxygOao/7DIx8fRaznDgETcgFTRmyfgaMtcGcgwQn3xff9N5nLIFhqfiaZ+UMl8LqfNAsIgqJz5rLPFSHNMGNf1PgTOUF48pLAK7pM10fSMKA38ZEihX9soBaRKwT4L0cAN7e2eG74HPC6jHxxqUrQOBZMjS8x7MUCpnQd7SuSglILXpPZfclVEXVVHlYGnKkAt7xK1iJr0/a+TbP2Jh0csVVkS6s7oK1oqo2gv2J6itQ1dHCtphP1jUja4WtXXBCMaV48h0fNUW8f9oQVhnuB7+CeoOwPE6IuWdrtNxDs+hMwainS/dxs=';
    // Init ChirpSDK
      await ChirpSDK.init(_appKey, _appSecret);
      // Set SDK config
      await ChirpSDK.setConfig(_appConfig);
  }

  Uint8List createChirp(String _userId, String _userSecret, String mode) {
    String hashedSecret = hashSecret(_userSecret);
    String payload;
    if(mode == 'register'){
    payload ='r' + _userId + hashedSecret;
    }else{
      payload ='n' + _userId + hashedSecret;
    }
    Uint8List _chirpData = utf8.encode(payload);
    return _chirpData;
  }

  Future<void> sendChirp(Uint8List _chirpData) async {
    await ChirpSDK.start();
    await ChirpSDK.send(_chirpData);
    sleep(Duration(seconds: 5));
    createToast('Chirp Sent');
    await ChirpSDK.stop();
  }

  //REGISTRATION FUNCTIONS
  Future<List> initRegistration() async{
    Firestore.instance.settings(persistenceEnabled: true);
    String idunique, user, email, name, mobilenumber, userid;
    final FirebaseMessaging messaging = FirebaseMessaging();
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      messaging.getToken().then((token) {
        idunique = token;
      });
      user  = await currentUser();
      email = await getEmailId();
      await db.collection('users').getDocuments().then((snapshot){
        snapshot.documents.forEach((f){
          if(f['authId']==user){
            userid = f['userId'];
            name = f['name'];
            mobilenumber = f['mobileNumber'];
          }
        });
      });
    } catch(e) {
      print(e);
    }
    return [idunique, user, email, name, mobilenumber, userid];
  }

  List createUserId() {
    String secret = '';
    String id = '';
    String set = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var rand = new Random();
    for (int i = 0; i < 16; i++) {
      var temp = rand.nextInt(62);
      secret += set[temp];
    }
    for (int i = 0; i < 15; i++) {
      var temp = rand.nextInt(62);
      id += set[temp];
    }
    return [id, secret];
  }

  void registerUser(String _userId, Map<String, String> json) async{
    try {
      await db.document('users/$_userId').setData(json);
    }catch (e) {
      print(e);
    }
  }

  void registerHome(String _userId, String _userSecret, String _homeId, String _homeName, Uint8List _chirpData, String _deviceToken) async{
    try {
      await db.document('users/$_userId/homes/$_homeId').setData({
        'secret':_userSecret,
        'homeName': _homeName
      });
      await db.document('homes/$_homeId/deviceTokens/$_deviceToken').setData({});
      sendChirp(_chirpData);
    }catch (e) {
      print(e);
    }
  }

  Future<bool> registerCheck(String _homeId, String _userId) async {
    Firestore.instance.settings(persistenceEnabled: true);
    List occupants=[];
    String name;
    await db.document('homes/$_homeId').collection('occupants').getDocuments().then((snapshot) {
      snapshot.documents.forEach((f) => occupants.add(f.documentID));
    });
    if(occupants.contains(_userId)){
      await db.document('users/$_userId').get().then((snapshot){
        name = snapshot['name'];
      });
      db.collection('users').getDocuments().then((snapshot){
        snapshot.documents.forEach((f) => {
          if(f['name']==name && f.documentID!=_userId){
            f.reference.delete()
          }
        });
      });
      return true;
    }
    return false;
  }

  //FORM VALIDATION FOR REGISTRATION AND LOGIN PAGES
  bool validateAndSave(formKey) {
    final form = formKey.currentState;
      if(form.validate()) {
        form.save();
        return true;
      }
      return false;
  }

  //BOTTOM TOAST
  void createToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIos: 1,
      backgroundColor: Colors.white,
      textColor: Colors.black,
      fontSize: 16.0
    );
  }

  //CREATE HASHED USERSECRET
  String hashSecret (String _userSecret) {
    var temp = new DateTime.now().millisecondsSinceEpoch;
    double time = temp/100000;
    String timestamp = time.toInt().toString();
    print(timestamp);
    var key = utf8.encode(timestamp);
    var secret = utf8.encode(_userSecret);
    var hmacSha1 = new Hmac(sha256, key); // HMAC-SHA256
    var digest = hmacSha1.convert(secret);
    print(digest);
    return digest.toString().substring(0,16);
  }

  Future<String> getPrimaryUser(String homeId) async{
    String primaryEmail;
    await db.document('homes/$homeId').get().then((snapshot) {
      primaryEmail = snapshot['master_email'];
    });
    return primaryEmail;
  }

  void sendMail(String primaryEmail, String userId, String otp) async{
    String username="intrusion.sls@gmail.com", password = "qwert123#", name, email, number;
    final smtpServer = gmail(username, password);
    await db.document('users/$userId').get().then((snapshot){
        name = snapshot['name'];
        email = snapshot['emailId'];
        number = snapshot['mobileNumber'];
    });
    final message = Message()   
    ..from = Address(username, 'Smart Locking System')
    ..recipients.add(primaryEmail)
    ..subject = 'A new user has registered, please validate.'
    ..text =    'Username: $name\nEmail: $email\nContact: $number\nOTP for this user is: $otp';

    try {
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } on MailerException catch (e) {
      print(e.toString());
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }

  void otpVerified(String homeId) async{
    String user = await currentUser();
    await db.collection('users').getDocuments().then((snapshot) {
      snapshot.documents.forEach((f) async {
        if(f.data['authId']==user){
          var userId = f.data['userId'];
          await db.document('homes/$homeId/occupants/$userId').setData({'valid':true});
          await db.document('homes/$homeId/occupants/$userId').get().then((snapshot){
            print(snapshot['valid']);
          });
        }
      });
    });
  }
}

class OtpArguments {
  final String primaryUser;
  final String otp;
  final String homeId;
  OtpArguments(this.primaryUser, this.otp, this.homeId);
}

class IntruderArguments {
  final String id;
  IntruderArguments(this.id);
}