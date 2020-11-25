import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_new/screens/cropping_screen.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../config.dart';
import 'getPremiumAccount.dart';
import 'referalCode.dart';
import 'review.dart';

class SettingsMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 60,
        decoration: new BoxDecoration(
            color: Colors.white,
            borderRadius: new BorderRadius.only(
                topLeft: const Radius.circular(20.0),
                topRight: const Radius.circular(20.0))),
        child: Center(
            child: InkWell(
                onTap: () async {

                  FirebaseAnalytics()
                      .logEvent(name: 'send_feedback', parameters: null);

                  final Email email = Email(
                    // body: 'Email body',
                    subject: '[magic crop feedback]',
                    recipients: ['connect@9592.tech'],
                    // cc: ['cc@example.com'],
                    // bcc: ['bcc@example.com'],
                    // attachmentPath: '/path/to/attachment.zip',
                  );

                  await FlutterEmailSender.send(email);
                },
                child: Container(
                    // padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Text(
                        "SEND FEEDBACK",
                        style: TextStyle(color: primaryColor, fontSize: 16),
                      ),
                    )))));
  }

  Switch buildSwitch() {
    return Switch.adaptive(
      activeTrackColor: primaryColor,
      focusColor: primaryColor,
      activeColor: primaryColor,
      value: true,
      onChanged: (value) {},
    );
  }

  RatingBar buildRating() {
    return RatingBar.builder(
      initialRating: 4,
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
    );
  }

  Widget buildField({Widget leading, String title, Widget trailing}) {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 20, bottom: 5),
      child: Row(
        children: [
          leading,
          Container(
              padding: const EdgeInsets.only(left: 20), child: Text(title)),
          if (trailing != null) ...trailingWidgets(trailing)
        ],
      ),
    );
  }

  List<Widget> trailingWidgets(Widget trailing) {
    return [
      Spacer(),
      trailing,
      SizedBox(
        width: 10,
      )
    ];
  }
}
