import 'package:flutter/material.dart';

import '../config.dart';
import '../screens/cropping_screen.dart';

class ReferalCode extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),

      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)
      ),
      child: Container(
        height: 380,
        width: MediaQuery.of(context).size.width * 0.9,
        child: Stack(
          children: [


            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 30,),

                Container(

                  height: 80,

                    child: Image.asset("assets/images/referal_code.png")),

                SizedBox(height: 5,),

                Text("\$2", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor), textAlign: TextAlign.center,),


                SizedBox(height: 10,),



                Text("Invite your friends to", textAlign: TextAlign.center,),
                SizedBox(height: 5,),
                Text("Get premium Features for a week", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center,),
                SizedBox(height: 5,),
                Text("when a friend uses your referral code", textAlign: TextAlign.center,),

                SizedBox(height: 20,),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey)
                  ),
                  height: 50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      Container(
                          padding: const EdgeInsets.only(left: 20),

                          child: Text("mgcinvtfrd")),
                      Container(
                          padding: const EdgeInsets.only(right: 20),

                          child: Icon(Icons.copy_rounded))
                    ],
                  ),
                ),
                SizedBox(height: 20,),

                buildFooterButton(context)



              ],
            ),

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



          ],
        ),
      ),
    );
  }

  Container buildFooterButton(BuildContext context) {
    return Container(
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

                      Image.asset("assets/images/send.png", height: 20, color: Colors.white,),
                      SizedBox(width: 5,),

                      Text("GET PREMIUM", style: TextStyle(color: Colors.white),)
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
