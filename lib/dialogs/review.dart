import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../config.dart';
import '../screens/cropping_screen.dart';

class Review extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),

      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)
      ),
      child: Container(
        height: 320,
        width: MediaQuery.of(context).size.width * 0.9,
        child: Stack(
          children: [


            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 30,),


                FittedBox(
                  child: Container(
                    padding: const EdgeInsets.only(left: 20, right: 50),
                    child: Text("Add Review To Get premium",style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold
                    ),),
                  ),
                ),
                SizedBox(height: 8,),

                FittedBox(
                  child: Container(
                    padding: const EdgeInsets.only(left: 20,right: 100),
                    child: Text("Features for a week",style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold
                    ),),
                  ),
                ),
                SizedBox(height: 5,),
                buildRating(),

                SizedBox(height: 20,),


                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextFormField(
                    autofocus: true,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "WRITE A REVIEW",
                      hintText: "WHAT DID YOU LIKE THE BEST?",
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)
                      ),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)
                      ),
                      hintStyle: TextStyle(
                        color: Colors.grey
                      ),

                      labelStyle: TextStyle(
                          color: Colors.black,
                        fontWeight: FontWeight.bold
                      ),
                  ),
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

            Icon(Icons.star, color: Colors.white,),
            SizedBox(width: 5,),

            Text("SUBMIT YOUR REVIEW", style: TextStyle(color: Colors.white),)
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
          Expanded(child: Text("Watch a video to get premium for this session", maxLines: 2, style: TextStyle(
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


  Widget buildRating() {
    return Container(
       width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: FittedBox(
        child: RatingBar.builder(
          itemSize: 20,
          initialRating: 3,
          minRating: 1,
          direction: Axis.horizontal,
          allowHalfRating: true,
          itemCount: 5,
          itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
          itemBuilder: (context, _) => Icon(
            Icons.star,
            color: primaryColor,
          ),
          onRatingUpdate: (rating) {
            print(rating);
          },
        ),
      ),
    );
  }
}
