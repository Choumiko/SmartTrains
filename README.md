SmartTrains
===========

### Creating Your First Smart Train Line
Todo.

### Train UI
Todo.

### Trainlines UI
Todo.

### Line Rules
![Line Rules UI](/readme_content/line_rules.png?raw=true "Line Rules UI")
- **Line #**: Todo.
- **Departure Conditions**
   - **Empty:** The train will depart the station when all cargo\tanker wagons are empty.
   - **Full:** The train will depart the station when all cargo\tanker wagons are full.
   - **Signal:** The train will depart the station when the circuit condition of the Smart Train Stop's signal lamp evaluates as true.
     - To set a condition on the lamp, attach a red or green wire to the lamp and then click the lamp.
   - **(And):** If checked, the train will be required to fulfil both the Signal and Empty or Full conditions.
- **Go To Station**
   - **Signal #:** The train will ignore the normal order of station on the line and travel to the station specified to the signal lamp.
   - **Station #:** The train will go to the station # specified in the text box.
   - The station the train will choose to depart to is determined in this order:
     - 1st, if Signal # is checked and the signal lamp has a valid station # input to it, the train will choose this station.
     - 2nd, if Station # is set to a valid station #, the train will choose this station.
     - Last, if neither of the previous are true, the train will proceed to the next station in the line.
- **Wait ∞:** The train will ignore the normal departure time and wait indefinitely until the departure conditions are met.

### Global Settings UI
Todo.

### Using train circuit output
Todo.

### Using train signal lamp
Todo.
