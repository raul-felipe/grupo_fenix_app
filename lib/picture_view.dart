import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class PictureView extends StatefulWidget {

  PictureView(var image, var definition){
    this.image=image;
    this.definition=definition;
  }
  var image;
  var definition;
  @override
  _PictureViewState createState() => _PictureViewState(image, definition);
}

class _PictureViewState extends State<PictureView> {

  _PictureViewState(var image, var definition){
    this.image=image;
    this.definition=definition;
  }

  var image;
  var definition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Menu"),
        leading: IconButton(
          icon: Icon(Icons.done),
          onPressed: () => Navigator.pop(context, definition),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            //height: MediaQuery.of(context).size.height * 0.80,
            child: PhotoView(
              imageProvider: image is File ? FileImage(image) : image.image,
            ),
          ),
          definition == null ?
          TextFormField(
            decoration: InputDecoration(
              hintText: 'Descrição',
            ),
            maxLines: null,
            initialValue: '',
            onChanged: (value) => definition = value,
          ):
          Text(
            definition,
            style: TextStyle(
              fontSize: 24,
            ),
          )
        ]
      )
    );
  }
}