POMODORO CITY - installing

1. Drag "Pomodoro City" onto the Applications folder.
2. Open Applications, RIGHT-CLICK (or Control-click) "Pomodoro City", choose Open,
   then click Open again in the dialog. You only need to do this the first time.
   (macOS asks because this app is not signed with a paid Apple developer account.)

If macOS says the app "is damaged" or still refuses to open, open Terminal and run:
   xattr -cr "/Applications/Pomodoro City.app"
then try step 2 again.

Your saved city and progress live in:
   ~/Library/Application Support/PomodoroCity/savegame.json
Updating the app never touches that file.
