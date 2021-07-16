import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grupo_fenix/class_cleaner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:grupo_fenix/qr_scanner.dart';

class CleanerMenuPage extends StatefulWidget {
  CleanerMenuPage(var user) {
    this.user = user;
  }
  var user;
  @override
  _CleanerMenuPageState createState() => _CleanerMenuPageState(user);
}

class _CleanerMenuPageState extends State<CleanerMenuPage>
    with TickerProviderStateMixin {
  _CleanerMenuPageState(var user) {
    this.user = user;
  }

  // QRCaptureController _captureController = QRCaptureController();
  // Animation<Alignment> _animation;
  // AnimationController _animationController;
  // String _captureText = '';
  Map user;
  // final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  // Barcode result;
  // QRViewController controller;

  @override
  void initState() {
    super.initState();
  }

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
            .doc(user["fila"].toString())
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
                if (snapshot.data.data == null) {
                  return Center(
                    child: Text(
                      "Nada por enquanto.",
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                List pre_salas = snapshot.data.data()['salas'];
                List salas = [];
                bool filaLimpa = true;
                for (int i = 0; i < pre_salas.length; i++) {
                  if (!pre_salas.elementAt(i)['limpo'] && pre_salas.elementAt(i)['relimpar']){
                    salas.add(pre_salas.elementAt(i));
                    filaLimpa = false;
                  }
                }
                for (int i = 0; i < pre_salas.length; i++) {
                  if (!pre_salas.elementAt(i)['limpo'] && !pre_salas.elementAt(i)['relimpar']){
                    salas.add(pre_salas.elementAt(i));
                    filaLimpa = false;
                  }
                }
                for (int i = 0; i < pre_salas.length; i++) {
                  if (pre_salas.elementAt(i)['limpo'])
                    salas.add(pre_salas.elementAt(i));
                }
                if(filaLimpa){
                  //resetar
                  for(int i = 0; i <pre_salas.length;i++){
                    pre_salas[i]['limpo']=false;
                    pre_salas[i]['relimpar']=false;
                  }
                  FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString())
                    .collection('fila').doc(user['fila']).set({'salas':pre_salas})
                    .then((value) => Fluttertoast.showToast(msg: 'Sua fila foi resetada'));
                }
                return new ListView.builder(
                    itemCount: salas.length,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return new ListTile(
                          title: new Text(salas.elementAt(index)['codigo']),
                          subtitle: new Text(salas.elementAt(index)['nome']),
                          trailing: salas.elementAt(index)['limpo']
                              ? Icon(Icons.check_circle)
                              : Icon(Icons.error),
                          onTap: () {
                            classClick(salas, index);
                          },
                        );
                      }
                      return new ListTile(
                        title: new Text(salas.elementAt(index)['codigo']),
                        subtitle: new Text(salas.elementAt(index)['nome']),
                        trailing: salas.elementAt(index)['limpo']
                            ? Icon(Icons.check_circle)
                            : Icon(Icons.error),
                      );
                    }
                  );
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
          onPressed: () => null),
    );
  }

  void classClick(var salas, var index) async {
    var scanResult =
        await Navigator.push(context, MaterialPageRoute(builder: (context) {
      return QRScanner();
    }));
    print(scanResult);
    if (scanResult == salas.elementAt(index)['codigo']) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ClassViewPage(
                salas.elementAt(index)['codigo'], new DateTime.now(), user)),
      );
    } else {
      Fluttertoast.showToast(msg: 'QRCode não confere com o ambiente');
    }
  }
}
