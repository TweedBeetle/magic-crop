import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:tip_dialog/tip_dialog.dart';

import 'ads.dart';
import 'screens/home_screen.dart';
import 'screens/cropping_screen.dart';

void main() {
  runApp(
    DevicePreview(
      // enabled: !kReleaseMode,
      enabled: false,
      builder: (context) => MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  // final ams = AdMobService();

  Widget build(BuildContext context) {
    // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    //   statusBarColor: Colors.transparent,
    // ));

    // RateMyApp rateMyApp = RateMyApp(
    //   preferencesPrefix: 'rateMyApp_',
    //   minDays: 7,
    //   minLaunches: 10,
    //   remindDays: 7,
    //   remindLaunches: 10,
    //   googlePlayIdentifier: 'fr.skyost.example',
    //   appStoreIdentifier: '1491556149',
    // );
    //
    // rateMyApp.init().then((_) {
    //   // if (rateMyApp.shouldOpenDialog) {
    //   if (true) {
    //     print('showing rating dialogue');
    //     rateMyApp.showRateDialog(
    //       context,
    //       title: 'Rate this app 1',
    //       // The dialog title.
    //       message: 'If you like this app, please take a little bit of your time to review it !\nIt really helps us and it shouldn\'t take you more than one minute.',
    //       // The dialog message.
    //       rateButton: 'RATE',
    //       // The dialog "rate" button text.
    //       noButton: 'NO THANKS',
    //       // The dialog "no" button text.
    //       laterButton: 'MAYBE LATER',
    //       // The dialog "later" button text.
    //       listener: (
    //           button) { // The button click listener (useful if you want to cancel the click event).
    //         switch (button) {
    //           case RateMyAppDialogButton.rate:
    //             print('Clicked on "Rate".');
    //             break;
    //           case RateMyAppDialogButton.later:
    //             print('Clicked on "Later".');
    //             break;
    //           case RateMyAppDialogButton.no:
    //             print('Clicked on "No".');
    //             break;
    //         }
    //
    //         return true; // Return false if you want to cancel the click event.
    //       },
    //       ignoreNativeDialog: true,
    //       // Set to false if you want to show the Apple's native app rating dialog on iOS or Google's native app rating dialog (depends on the current Platform).
    //       dialogStyle: DialogStyle(),
    //       // Custom dialog styles.
    //       onDismissed: () =>
    //           rateMyApp.callEvent(RateMyAppEventType
    //               .laterButtonPressed), // Called when the user dismissed the dialog (either by taping outside or by pressing the "back" button).
    //       // contentBuilder: (context, defaultContent) => content, // This one allows you to change the default dialog content.
    //       // actionsBuilder: (context) => [], // This one allows you to use your own buttons.
    //     );
    //   }
    // });
    //
    return MaterialApp(
      locale: DevicePreview
          .of(context)
          .locale,
      // <--- /!\ Add the locale
      builder: DevicePreview.appBuilder,
      title: 'Magic Crop',
      theme: new ThemeData(
        primarySwatch: Colors.teal,
        canvasColor: Colors.transparent,
      ),
      home: HomePage(),
    );


    return RateMyAppBuilder(
      builder: (context) => MaterialApp(
        locale: DevicePreview.of(context).locale,
        // <--- /!\ Add the locale
        builder: DevicePreview.appBuilder,
        title: 'Magic Crop',
        theme: new ThemeData(
          primarySwatch: Colors.teal,
          canvasColor: Colors.transparent,
        ),
        home: HomePage(),
      ),
      rateMyApp: RateMyApp(
        preferencesPrefix: 'rateMyApp_',
        minDays: 0,
        minLaunches: 0,
        remindDays: 0,
        remindLaunches: 0,
        googlePlayIdentifier: 'tech.nine_five_nine_two.magic_crop',
        appStoreIdentifier: '',// TODO
      ),
      onInitialized: (context, rateMyApp) {
        // Called when Rate my app has been initialized.

        rateMyApp.conditions.forEach((condition) {
          if (condition is DebuggableCondition) {
            print(condition
                .valuesAsString + ' ${condition.isMet}'); // We iterate through our list of conditions and we print all debuggable ones.
          } else {
            print(condition);
          }
        });

        print('Are all conditions met ? ' +
            (rateMyApp.shouldOpenDialog ? 'Yes' : 'No'));

        // if (rateMyApp.shouldOpenDialog) {
        if (true) {
          rateMyApp.showRateDialog(
            context,
            title: 'Rate this app', // The dialog title.
            message: 'If you like this app, please take a little bit of your time to review it !\nIt really helps us and it shouldn\'t take you more than one minute.', // The dialog message.
            rateButton: 'RATE', // The dialog "rate" button text.
            noButton: 'NO THANKS', // The dialog "no" button text.
            laterButton: 'MAYBE LATER', // The dialog "later" button text.
            listener: (button) { // The button click listener (useful if you want to cancel the click event).
              switch(button) {
                case RateMyAppDialogButton.rate:
                  print('Clicked on "Rate".');
                  break;
                case RateMyAppDialogButton.later:
                  print('Clicked on "Later".');
                  break;
                case RateMyAppDialogButton.no:
                  print('Clicked on "No".');
                  break;
              }

              return true; // Return false if you want to cancel the click event.
            },
            ignoreNativeDialog: true, // Set to false if you want to show the Apple's native app rating dialog on iOS or Google's native app rating dialog (depends on the current Platform).
            dialogStyle: DialogStyle(), // Custom dialog styles.
            onDismissed: () => rateMyApp.callEvent(RateMyAppEventType.laterButtonPressed), // Called when the user dismissed the dialog (either by taping outside or by pressing the "back" button).
            // contentBuilder: (context, defaultContent) => content, // This one allows you to change the default dialog content.
            // actionsBuilder: (context) => [], // This one allows you to use your own buttons.
          );

        }
      },
    );

    // return MaterialApp(
    //   locale: DevicePreview.of(context).locale, // <--- /!\ Add the locale
    //   builder: DevicePreview.appBuilder,
    //   title: 'Magic Crop',
    //   theme: new ThemeData(
    //     primarySwatch: Colors.teal,
    //     canvasColor: Colors.transparent,
    //   ),
    //   home: HomePage(),
    //   // home: Stack(children: [HomePage(),
    //   //       TipDialogContainer(duration: const Duration(seconds: 1))],)
    // );
  }
}
