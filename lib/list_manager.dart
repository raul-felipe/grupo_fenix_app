import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grupo_fenix/class_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:grupo_fenix/qr_scanner.dart';

class ManagerMenuPage extends StatefulWidget {
  ManagerMenuPage(var user) {
    this.user = user;
  }
  var user;
  @override
  _ManagerMenuPageState createState() => _ManagerMenuPageState(user);
}

class _ManagerMenuPageState extends State<ManagerMenuPage> {
  _ManagerMenuPageState(var user) {
    this.user = user;
  }

  Map user;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Menu"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clientes')
            .doc(user['cliente'].toString())
            .collection('fila')
            .doc(user['cpf'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return new Text('Error: ${snapshot.error}');
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Center(
                  child: Text(
                "Carregando...",
                textAlign: TextAlign.center,
              ));
            case ConnectionState.active:
              {
                if (snapshot.data.data == null ||
                    snapshot.data.data()['salas'].length == 0) {
                  return Center(
                      child: Text(
                    "Nada por enquanto.",
                    textAlign: TextAlign.center,
                  ));
                }
                List managerList = snapshot.data.data()['salas'];
                return new ListView.builder(
                    itemCount: managerList.length,
                    itemBuilder: (context, index) {
                      return new ListTile(
                        title: new Text(managerList.elementAt(index)['codigo']),
                        subtitle:
                            new Text(managerList.elementAt(index)['nome']),
                        trailing: Icon(Icons.error),
                        onTap: () {
                          classClick(managerList, index);
                        },
                      );
                    });
              }
            default:
              return Center(
                child: Text(
                  "Nada por enquanto.",
                  textAlign: TextAlign.center,
                ),
              );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Padding(
          child: Image.asset("images/qrcode_icon.png"),
          padding: EdgeInsets.all(12),
        ),
        onPressed: () => null,
      ),
    );
  }

  void classClick(var managerList, var index) async {
    var scanResult =
        await Navigator.push(context, MaterialPageRoute(builder: (context) {
      return QRScanner();
    }));
    print(scanResult);
    if (scanResult == managerList.elementAt(index)['codigo']) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ClassManagerPage(
                managerList.elementAt(index)['codigo'],
                new DateTime.now(),
                user,
                managerList.elementAt(index)['fila'])),
      );
    } else {
      Fluttertoast.showToast(msg: 'QRCode não confere com o ambiente');
    }
  }
}
