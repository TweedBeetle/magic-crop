import 'package:flutter/material.dart';

import '../config.dart';
import '../screens/cropping_screen.dart';

class PremiumAccount extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10)
      ),
      child: Container(
        height: 390,
        width: MediaQuery.of(context).size.width * 0.9,
        child: Stack(
          children: [
            Positioned(
              top: 15,
              right: 10,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  height: 30,
                  width: 30,
                  child: CircleAvatar(
                    child: Icon(
                      Icons.close,
                      color: Colors.black,
                    ),
                    backgroundColor: secondaryColor,
                  ),
                ),
              ),
            ),


            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 10,),
                Container(
                  alignment: Alignment.center,
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)
                    ),
                    child: Container(

                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(25)),
                        child: Icon(
                          Icons.star,
                          color: Colors.yellow,
                          size: 50,
                        )),
                  ),
                ),

                SizedBox(height: 10,),

                Text("Premium features for ever ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                SizedBox(height: 5,),

                Text("\$2", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor), textAlign: TextAlign.center,),


                SizedBox(height: 10,),

                buildField(title: "Rescaling to scales other than 1:1"),
                buildField(title: "50 % better image resolution"),
                buildField(title: "Remove All ads"),

                SizedBox(height: 10,),
                buildYoutubeAd(),
                SizedBox(height: 10,),

                Container(
                  height: 50,
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: RaisedButton(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)
                    ),
                    color: primaryColor,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        SizedBox(width: 20,),
                        Image.asset("assets/images/crown_dialog.png", height: 50,),
                        Container(child: Text("GET PREMIUM", style: TextStyle(color: Colors.white),), padding: const EdgeInsets.only(right: 30),)
                      ],
                    ),
                  ),
                )



              ],
            ),




          ],
        ),
      ),
    );
  }

  Container buildYoutubeAd() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.only(left: 10, right: 10),

      decoration: BoxDecoration(
          color: secondaryColor,
          borderRadius: BorderRadius.circular(10)
      ),
      height: 60,
                child: Row(
                  children: [
                    Image.asset("assets/images/youtube.png", height: 30, color: primaryColor,),
                    SizedBox(width: 10,),
                    Expanded(child: Text("Watch a video to get premium for a week", maxLines: 2, style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor
                    ),))


                  ],
                ),
              );
  }

  Widget buildField({String title}) {
    return Container(
      height: 30,
      child: Row(
        children: [
          SizedBox(width: 20,),

          ClipRRect(
            clipBehavior: Clip.hardEdge,
            borderRadius: BorderRadius.all(Radius.circular(25)),
            child: SizedBox(
              width: Checkbox.width,
              height: Checkbox.width,
              child: Container(
                decoration: new BoxDecoration(

                  borderRadius: new BorderRadius.circular(25),
                ),
                child: Theme(
                  data: ThemeData(
                    unselectedWidgetColor: Colors.transparent,
                  ),
                  child: Checkbox(
                    value: true,
                    onChanged: (state) {

                    },

                    activeColor: primaryColor,
                    checkColor: Colors.white,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10,),
          Text(title)
        ],
      ),
    );
  }
}
