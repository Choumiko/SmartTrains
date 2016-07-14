SmartTrains
===========

Creating Your First Smart Train Line
---
Todo.

Train UI
---
![Train UI](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/readme_content/train_ui.png "Train UI")
- **Train: Choumiko (L-CCC-L):** The name and type of the train. In this case: 3 wagons (C) with a locomotive (L) at the front and end. The type is used to determine the refueling station for Autorefuel.
- Displays an overview of the trains schedule and rules
- **Save as line:** Saves the trains schedule as a line.

Trainlines UI
---
![Trainlines UI](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/readme_content/trainline_ui.png "Trainlines UI")
Todo: add text

Line Rules
---
![Line Rules UI](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/readme_content/line_rules.png "Line Rules UI")
- **Line #:** Outputs the assigned line number at a smart train stop.
- **use station mapping:** Maps the numbers passed via Signal # or Station # to different stations
- **Go To Station**
   - **Signal #:** The train will ignore the normal order of station on the line and travel to the station specified to the signal lamp.
   - **Station #:** The train will go to the station # specified in the text box.
   - The station the train will choose to depart to is determined in this order:
     - 1st, if Signal # is checked and the signal lamp has a valid station # input to it, the train will choose this station.
     - 2nd, if Station # is set to a valid station #, the train will choose this station.
     - Last, if neither of the previous are true, the train will proceed to the next station in the line.
     - **Note:** If the train leaves due to the waiting time passed, it will always go to the next station.

Station Mapping
---
![Station Mapping](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/readme_content/station_mapping.png "Station Mapping")
- Accessible when opening a station GUI.
- Allows stations to be assigned a number. If a line has "Use station mapping" selected, it will try and go to the station with the corresponding number when used with the Signal # or Station # rule. (As opposed to going to the station at the number in the schedule)
- Todo: make that description less confusing..

Refuel
---
- Checking Refuel in the trainline or train UI will add a refueling station to the end of the trains schedule, once that train needs refueling and remove it once it is done.
- The refueling stations name is "Refuel L-CCC-L" for a train with type L-CCC-L. If no such station exists, it will use "Refuel" as the station name.
- Trains like L-CCC, L-CCCCCCCCCCC will look for a station named "Refuel L"

Global Settings UI
---
![Global Settings](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/readme_content/global_settings.png "Global Settings")
- **Refueling:** Sets the lower and upper limits for available fuel. If any locomotive of a train is below the lower limit, it will add the refueling station, if all are above the upper limit again it will get removed.
- **Min flow rate:** Used for the railtanker mod with the "No change" rule. If the amount of liquid in a tanker has changed by less than that rate, it is considered to be equal. With default settings: If it doesn't change by more than 2 units in 2 seconds the "No change" rule is considered true.
- **Update intervals:** Number of ticks between checking the rules/updating the constant combinators at smart trainstops. For most saves the default values should be fine.

Using train circuit output
---
- **Signals when a train is at a smart trainstop:**
 - ![Signal cargo wagons](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/graphics/signal_cargowagons.png "Signal cargo wagons") : Number of cargo wagons
 - ![Signal locomotives](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/graphics/signal_locomotives.png?raw=true "Signal locomotives") : Number of locomotives
 - ![Signal passengers](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/graphics/signal_passenger.png?raw=true "Signal passengers") : Number of players in the train
 - ![Signal train at station](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/graphics/signal_train_at_station.png?raw=true "Signal train at station") : 1 if a train is at the station, 0 otherwise
 - ![Signal line #](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/graphics/signal_line.png?raw=true "Signal line #") : The line number assigned to the trains line, 0 if not on a line
 - ![Signal lowest fuel](https://raw.githubusercontent.com/Choumiko/SmartTrains/master/graphics/signal_lowest_fuel.png?raw=true "Signal lowest fuel") : The lowest fuel in a locomotive of a train (in MJ)
 - Additionally it outputs the trains cargo

Using train signal lamp
---
Todo.
