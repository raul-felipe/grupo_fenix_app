import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:grupo_fenix/list_cleaner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grupo_fenix/list_manager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Define a top-level named handler which background/terminated messages will
/// call.
///
/// To verify things are working, check out the native platform logs.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.getToken();
  print('Handling a background message ${message.messageId}');
}

/// Create a [AndroidNotificationChannel] for heads up notifications
AndroidNotificationChannel channel;

/// Initialize the [FlutterLocalNotificationsPlugin] package.
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await FirebaseMessaging.instance.getToken();

  // Set the background messaging handler early on, as a named top-level function
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Create an Android Notification Channel.
  ///
  /// We use this channel in the `AndroidManifest.xml` file to override the
  /// default FCM channel to enable heads up notifications.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  /// Update the iOS foreground notification presentation options to allow
  /// heads up notifications.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grupo Fenix',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: MyHomePage(title: 'Login'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var rg = '';
  var cpf = '';

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp().whenComplete(() {
      FirebaseMessaging.instance.getToken();

      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage message) {
        if (message != null) {
          //Navigator.pushNamed(context, '/message',arguments: MessageArguments(message, true));
        }
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // RemoteNotification notification = message.notification;
        // AndroidNotification android = message.notification?.android;
        if (message.data != null) {
          flutterLocalNotificationsPlugin.show(
              0,
              "Novas alterações",
              message.data['message'],
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channel.description,
                  // TODO add a proper drawable resource to android, for now using
                  //      one that already exists in example app.
                  icon: 'launch_background',
                ),
              ));
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('A new onMessageOpenedApp event was published!');
        //Navigator.pushNamed(context, '/message', arguments: MessageArguments(message, true));
      });
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Image.asset(
                      "images/grupo_fenix.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                  Divider(
                    height: 16,
                    color: Colors.transparent,
                  ),
                  Divider(
                    height: 16,
                    color: Colors.transparent,
                  ),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "CPF",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(32.0)),
                    ),
                    onChanged: (value) {
                      cpf = value;
                    },
                  ),
                  Divider(
                    height: 16,
                    color: Colors.transparent,
                  ),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "RG",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(32.0)),
                    ),
                    onChanged: (value) {
                      rg = value;
                    },
                  ),
                  Divider(
                    height: 16,
                    color: Colors.transparent,
                  ),
                  ElevatedButton(
                    style: ButtonStyle(
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(30.0)))),
                    child: Text("Entrar"),
                    onPressed: () {
                      if (cpf == '' || rg == '')
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('Favor preencher todos os campos.'),
                          ),
                        );
                      else {
                        FirebaseFirestore.instance
                            .collection("usuario")
                            .doc(cpf)
                            .get()
                            .then((snap) async {
                          var user = snap.data();
                          if (user == null || user['rg'] != rg)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Dados não conferem.'),
                              ),
                            );
                          else {
                            //salva o token do dispositivo no usuario de login
                            await FirebaseFirestore.instance
                                .collection('usuario')
                                .doc(cpf)
                                .update({
                              'tokens': FieldValue.arrayUnion([
                                await FirebaseMessaging.instance.getToken()
                              ]),
                            });
                            if (user['tipo'] == 'limpeza') {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        CleanerMenuPage(user)),
                              );
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        ManagerMenuPage(user)),
                              );
                            }
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
