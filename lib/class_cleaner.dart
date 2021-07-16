import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grupo_fenix/picture_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:progress_dialog/progress_dialog.dart';

class ClassViewPage extends StatefulWidget {
  ClassViewPage(String idSala, DateTime lastEntry, var user) {
    this.idSala = idSala;
    this.lastEntry = lastEntry;
    this.user = user;
  }
  DateTime lastEntry;
  String idSala;
  var user;
  @override
  _ClassViewState createState() => _ClassViewState(idSala, lastEntry, user);
}

class _ClassViewState extends State<ClassViewPage>
    with AutomaticKeepAliveClientMixin<ClassViewPage> {

  List<Widget> _images = [Container(color: Colors.blue,height: 200,width: 200,)];
  var _pick = [];

  Reference storageReference = FirebaseStorage.instance.ref().child("imagens");

  String idSala;
  DateTime lastEntry;
  var user;
  var snap;
  var appropriate;

  Stream<DocumentSnapshot> _stream;

  _ClassViewState(String idSala, DateTime lastEntry, var user) {
    this.idSala = idSala;
    this.lastEntry = lastEntry;
    this.user = user;
  }

  
  @override
  void initState() {
    super.initState();
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
                    snap['manager_obs'] != null ?
                    Text('Observação: '+ snap['manager_obs']):
                    Container(),
                    Expanded(
                      child: screenBase()
                    ),
                  ],
                );
              }
          }
        },
      ),
    );
  }

  Widget managerImage(snap, keys, index){
    return Image.network(
              snap["definitions"][keys[index]]["image"],
              height: 200,
              width: 200,
              loadingBuilder: (BuildContext context, Widget child,ImageChunkEvent loadingProgress){
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null ? 
                        loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes
                        : null,
                  ),
                );
              },
            );
  }

  //botao de tirar foto
  Widget addImage(){
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

  Widget sendButton(){
    return RaisedButton(
      onPressed: () async {
        if(_images.length<2){
          return showDialog(
            context: context,
            builder: (BuildContext context){
              return AlertDialog(
                title: Text('Ainda sem fotos'),
                content: Text('Antes de enviar, tire pelo menos uma foto do ambiente após a limpeza.'),
              );
            });          
        }
        ProgressDialog pr = new ProgressDialog(context, type: ProgressDialogType.Normal);
        snap["cleaner_images"] = [];
        pr.show();
        //envia as fotos para o firebase
        for (int i = 0; i < _pick.length; i++) {
          await storageReference.child(idSala).child("images").child(i.toString()).putFile(_pick[i]['file']);
          snap["cleaner_images"].add({
            'definition': _pick.elementAt(i)['definition'],
            'url': (await storageReference.child(idSala).child("images").child(i.toString()).getDownloadURL()).toString()
          });
        }

        WriteBatch batch = FirebaseFirestore.instance.batch();

        //atualizacao da sala
        Map<String, dynamic> classMap = new Map();
        classMap["definitions"] = appropriate;
        classMap["last_user"] = user["cpf"];
        classMap["start_at"] = lastEntry;
        classMap["finish_at"] = new DateTime.now();
        classMap["cleaner_images"] = snap["cleaner_images"];
        classMap['checked_at'] = null;
        classMap["manager_images"] = null;
        classMap['cleaner_obs'] = snap['cleaner_obs'];
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

        //atualizacao da fila
        DocumentSnapshot fila = await FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('fila').doc(user["fila"].toString()).get();
        List salas = fila.data()['salas'];
        for(int i = 0; i < salas.length; i++){
          if(salas.elementAt(i)['codigo']==idSala){
            salas.elementAt(i)['limpo'] = true;
            salas.elementAt(i)['relimpar'] = false;
          }
        }
        Map<String, dynamic> filaMap = new Map();
        filaMap["salas"] = salas;

        batch.update(FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('fila').doc(user["fila"].toString()), filaMap);
        // await FirebaseFirestore.instance
        //     .collection('clientes')
        //     .doc(user['cliente'].toString())
        //     .collection('fila')
        //     .doc(user["fila"].toString())
        //     .update(filaMap);

        //atualizacao da lista do gerente
        DocumentSnapshot managerSnapshot = await FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('fila').doc(user['cpf_gerente']).get();
        List manager = managerSnapshot.data()['salas'];
        manager.add({
          'codigo': idSala,
          'nome': snap['class_name'],
          'fila': user["fila"].toString()
        });

        Map<String, dynamic> managerMap = new Map();
        managerMap["salas"] = manager;

        batch.update(FirebaseFirestore.instance.collection('clientes').doc(user['cliente'].toString()).collection('fila').doc(user['cpf_gerente']), managerMap);
        // await FirebaseFirestore.instance
        //     .collection('clientes')
        //     .doc(user['cliente'].toString())
        //     .collection('fila')
        //     .doc(user['cpf_gerente'])
        //     .update(managerMap);
        
        batch.commit().then((value){
          pr.hide();
          Navigator.pop(context);
        }).catchError((error){
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

  Widget bottom(){
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
            onChanged: (value) => snap['cleaner_obs'] = value,
            decoration: InputDecoration(
              hintText: 'Detalhes'
            ),
          ),
          sendButton(),
        ],
      )
    );
  }
  
  Widget screenBase() {
    List keys = snap["definitions"].keys.toList();
    _images[0] = addImage();
    int plus = 1;
    if(snap["manager_images"] != null){
      plus++;
    }
    return ListView.builder(
      itemCount: keys.length + plus,
      itemBuilder: (context, index) {
        if (index == keys.length + plus - 1) {
          return bottom();
        }
        if (index==0 && plus==2){
          List <Widget> _managerImages = [];
          for(int i = 0;i<snap["manager_images"].length;i++){
            _managerImages.add(
              GestureDetector(
                child: CircleAvatar(
                  radius: 50.0,
                  backgroundImage:
                  NetworkImage(
                    snap["manager_images"][i]['url'],
                    scale: 100,

                  ),
                ),
                onTap: (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PictureView(Image.network(snap["manager_images"][i]['url']), snap['manager_images'][i]['definition'])),
                  );
                },
              ),
            //   Image.network(
            //   snap["manager_images"][i]['url'],
            //   height: 200,
            //   width: 200,
            //   loadingBuilder: (BuildContext context, Widget child,ImageChunkEvent loadingProgress){
            //     if (loadingProgress == null) return 
            //       GestureDetector(
            //         child: child,
            //         onTap: () {
            //           Navigator.push(
            //             context,
            //             MaterialPageRoute(builder: (context) => PictureView(_managerImages.elementAt(i), snap['manager_images'][i]['definition'])),
            //           );
            //         },
            //       );
            //     //child;
            //     return Center(
            //       child: CircularProgressIndicator(
            //       value: loadingProgress.expectedTotalBytes != null ? 
            //             loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes
            //             : null,
            //       ),
            //     );
            //   },
            // )
            );
          }
          if(_managerImages.length==0)return Container();
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
                      children: _managerImages,
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
