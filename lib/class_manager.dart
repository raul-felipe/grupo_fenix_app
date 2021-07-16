import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grupo_fenix/picture_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:progress_dialog/progress_dialog.dart';

class ClassManagerPage extends StatefulWidget {
  ClassManagerPage(String idSala, DateTime lastEntry, var user, String fila) {
    this.idSala = idSala;
    this.lastEntry = lastEntry;
    this.user = user;
    this.fila = fila;
  }
  DateTime lastEntry;
  String idSala;
  var user;
  String fila;

  @override
  _ClassManagerState createState() => _ClassManagerState(idSala, lastEntry, user, fila);
}

class _ClassManagerState extends State<ClassManagerPage>
    with AutomaticKeepAliveClientMixin<ClassManagerPage> {
  Stream<DocumentSnapshot> _stream;

  List<Widget> _images = [Container(color: Colors.blue,height: 200,width: 200,)];
  var _pick = [];

  Reference storageReference = FirebaseStorage.instance.ref().child("imagens");

  String idSala;
  DateTime lastEntry;
  var user;
  var snap;
  Map appropriate;
  String fila;

  _ClassManagerState(String idSala, DateTime lastEntry, var user, String fila) {
    this.idSala = idSala;
    this.lastEntry = lastEntry;
    this.user = user;
    this.fila = fila;
    _stream = FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('salas').doc(idSala).snapshots();
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(idSala),
      ),
      body: StreamBuilder(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return new Text('Error: ${snapshot.error}');
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return new Text('Loading...');
            default:
              {
                snap = snapshot.data.data();
                if(appropriate == null){
                  appropriate = snap['definitions'];
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    snap['finish_at'] is Timestamp ?
                    Text("Ultima limpeza: " + (DateTime.parse(snap['finish_at'].toDate().toString())).toString()):
                    Text("Ultima limpeza: -"),
                    snap['checked_at'] is Timestamp ? 
                    Text("Ultima checagem: " + (DateTime.parse(snap['checked_at'].toDate().toString())).toString()):
                    Text("Ultima checagem: -"),
                    snap['cleaner_obs'] != null ?
                    Text('Observação: '+ snap['cleaner_obs']):
                    Container(),
                    Expanded(
                      child: screenBase(snap)
                    ),
                  ],
                );
              }
          }
        },
      ),
    );
  }

  //botao de tirar foto
  Widget addImage(snap){
    return Container(
      height: 50,
      width: 50,
      child: IconButton(
              icon: Icon(Icons.camera_alt),
              onPressed: () async {
                var image =
                    await ImagePicker.pickImage(
                      source: ImageSource.camera,
                      maxHeight: 720,
                      maxWidth: 720,
                    );
                setState(() {
                  _pick.add({
                    'file': image,
                    'definition': ''
                  });
                  _images.add(
                    GestureDetector(
                      child: CircleAvatar(
                        radius: 50.0,
                        backgroundImage: FileImage(
                          image,
                        )
                      ),
                      onTap: () async {
                        _pick.elementAt(_pick.length-1)['definition'] = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PictureView(image, null)),
                        );
                      },
                    )
                  );
                });
              },
            ),
    );
  }

  Widget sendButton(snap){
    return RaisedButton(
      onPressed: () async {
        if(_images.length<2){
          AlertDialog(
            title: Text('Ainda sem fotos'),
            content: Text('Antes de enviar, tire pelo menos uma foto do ambiente após a limpeza.'),
          );
        }
        ProgressDialog pr = new ProgressDialog(context, type: ProgressDialogType.Normal);
        snap["manager_images"] = [];
        pr.show();
        for (int i = 0; i < _pick.length; i++) {
          await storageReference.child(idSala).child("images").child(i.toString()).putFile(_pick[i]['file']);
          snap["manager_images"].add({
            'definition': _pick.elementAt(i)['definition'],
            'url': (await storageReference.child(idSala).child("images").child(i.toString()).getDownloadURL()).toString()
          });
        }

        WriteBatch batch = FirebaseFirestore.instance.batch();

        //atualizar valores da sala
        Map<String, dynamic> classMap = new Map();
        classMap["definitions"] = appropriate;
        classMap["last_user"] = user["cpf"];
        classMap["start_at"] = lastEntry;
        classMap["finish_at"] = null;
        classMap["checked_at"] = new DateTime.now();
        classMap["manager_images"] = snap["manager_images"];
        classMap["cleaner_images"] = null;
        classMap['manager_obs'] = snap['manager_obs'];
        batch.update(FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('salas').doc(idSala), classMap);
        // await FirebaseFirestore.instance
        //     .collection('clientes')
        //     .doc(user['cliente'].toString())
        //     .collection('salas')
        //     .doc(idSala)
        //     .update(classMap);

        //adiciona idSala ao classmap e atualiza o historico
        classMap['id'] = idSala;
        classMap['date'] = DateTime.now();
        batch.set(FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('historico').doc(), classMap);
        // await FirebaseFirestore.instance
        //     .collection('clientes')
        //     .doc(user['cliente'].toString())
        //     .collection('historico')
        //     .doc()
        //     .set(classMap);

        //atualizar a lista da fila de limpeza
        DocumentSnapshot filaSnapshot = await FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('fila').doc(fila).get();
        List filaList = filaSnapshot.data()['salas'];

        for(int i = 0; i < filaList.length;i++){
          if(filaList.elementAt(i)['codigo']==idSala){
            bool limpo = true;
            appropriate.forEach((key, value) {
              if(value['appropriate'] == false)
                limpo=false;
            });
            if(limpo == false){
              filaList.elementAt(i)['limpo']=false;
              filaList.elementAt(i)['relimpar'] = true;
            }
          }
        }
        batch.update(FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('fila').doc(fila), {'salas':filaList});
        //await FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('fila').doc(fila).update({'salas':filaList});

        //remover sala da lista da gerencia
        DocumentSnapshot managerSnapshot = await FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('fila').doc(user['cpf']).get();
        List manager = managerSnapshot.data()['salas'];

        for(int i = 0; i < manager.length;i++){
          if(manager.elementAt(i)['codigo']==idSala){
            manager.removeAt(i);
          }
        }

        Map<String, dynamic> managerMap = new Map();
        managerMap["salas"] = manager;

        batch.update(FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('fila').doc(user['cpf']), managerMap);
        // await FirebaseFirestore.instance
        //     .collection('clientes')
        //     .doc(user['cliente'].toString())
        //     .collection('fila')
        //     .doc(user['cpf'])
        //     .update(managerMap);

        batch.commit().then((value){
          pr.hide();
          Navigator.pop(context);
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Houve um erro: $error")));
        });
        // pr.hide();
        // Navigator.pop(context);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      child: Text("Enviar"),
    );
  }

  Widget definitionCard(index, keys){
    return Card(
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(keys.elementAt(index),
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  Switch(
                    value: appropriate[keys[index]]['appropriate'],
                    onChanged: (value) {
                      setState(() {
                        appropriate[keys[index]]['appropriate'] = value;
                      });
                    },
                  ),
                ],
              ),
              // Divider(),
              // ListView(
              //   physics: NeverScrollableScrollPhysics(),
              //   shrinkWrap: true,
              //   children: defs,
              // ),
            ]),
          ),
        );
  }

  Widget bottom(snap){
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          Container(
            margin: EdgeInsets.symmetric(vertical: 20.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _images,
              ),
            ),
          ),
          TextField(
            onChanged: (value) => snap['manager_obs'] = value,
            decoration: InputDecoration(
              hintText: 'Detalhes'
            ),
          ),
          sendButton(snap),
        ],
      )
    );
  }
  
  Widget screenBase(snap) {
    List keys = snap["definitions"].keys.toList();
    _images[0] = addImage(snap);
    int plus = 1;
    if(snap["cleaner_images"] != null){
      plus++;
    }
    return ListView.builder(
      itemCount: keys.length + plus,
      itemBuilder: (context, index) {
        if (index == keys.length + plus - 1) {
          return bottom(snap);
        }
        if (index==0 && plus==2){
          List <Widget> _cleanerImages = [];
          for(int i = 0;i<snap["cleaner_images"].length;i++){
            _cleanerImages.add(
              GestureDetector(
                child: CircleAvatar(
                  radius: 50.0,
                  backgroundImage:
                  NetworkImage(
                    snap["cleaner_images"][i]['url'],
                    scale: 100,

                  ),
                ),
                onTap: (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PictureView(Image.network(snap["cleaner_images"][i]['url']), snap['cleaner_images'][i]['definition'])),
                  );
                },
              ),
            );
          }
          if(_cleanerImages.length==0)return Container();
          else return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                Container(
                  margin: EdgeInsets.symmetric(vertical: 20.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _cleanerImages,
                    ),
                  ),
                ),
              ],
            )
          );
        }
        return definitionCard(index-(plus-1), keys);
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
