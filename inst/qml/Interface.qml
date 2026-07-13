//
// Copyright (C) 2013-2018 University of Amsterdam
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see
// <http://www.gnu.org/licenses/>.
//
import QtQuick
import QtQuick.Layouts
import JASP.Controls
import JASP.Widgets
import JASP

Form
{

  info: qsTr("This analysis shows you different interface elements of JASP, such as tick marks, text boxes, ... \\
  Its purpose is pedagogical, and its target audience is that of JASP module developers. \\
  \\
  From the technical point of view, the most challenging part of JASP module development is the communication between the QML interface and the R backend. \\
  Playing with the current JASP analysis while simultaneously inspecting the R code in the files `./inst/qml/Interface.qml` and `./R/examples.R` is a good way to learn how this communication works. \\
  \\
  The source code is available at [github.com/jasp-stats/jaspModuleTemplate](https://github.com/jasp-stats/jaspModuleTemplate)")

  Text
  {
      text: qsTr("This analysis shows you different interface elements of JASP")
	  // The qsTr wrapper allows for future translations. As a rule of thumb, you should always use qsTr for any text that will be displayed to the user.
  }

	Group
	{
		title: qsTr("Logical controls")

		CheckBox
		{
			info: qsTr("This is a tick mark that can be used to control the flow of the analysis")

			name: "my_tick_mark"
			label: qsTr("Tick mark")

			// We can add some extra control parameters
			checked: false // Default value
		}

		RadioButtonGroup
		{
			name: "radio_buttons"
			title: qsTr("Radio buttons")

			RadioButton { value: "one value"; label: qsTr("One"); checked: true } // Single-line definition is also possible
			RadioButton { value: "another value"; label: qsTr("Another") }
		}
	}

	Group
	{
		title: qsTr("Other controls")

		DropDown
		{
			info: qsTr("This is a dropdown that can be used to select one of a list of options")

			name: "my_dropdown"
			label: qsTr("Select an option")

			// We can add some extra control parameters
			values: ["option 1", "option 2", "option 3"]
		}

		Slider
		{

			info: qsTr("This is a slider that can be used to select a value in a range")

			name: "my_slider"
			label: qsTr("Select a value")

			// We can add some extra control parameters
			min: 0
			max: 1
			value: 0.5
			decimals: 3
			vertical: false
		}
	}

	Group
	{
		title: qsTr("Keyboard inputs")

		IntegerField
		{
			info: qsTr("This is the number that will be used in the operation")

			name: "my_integer"                // This will map to options$my_integer in R
			label: qsTr("Input an integer")   // qsTr allows for future translations

			// We can add some extra control parameters
			min: 1
			defaultValue: 10
			fieldWidth: 50
			max: 1000
		}

		DoubleField
		{
			info: qsTr("This is the number that will be used in the operation")

			name: "my_double"
			label: qsTr("Input a number with decimals")

			// We can add some extra control parameters
			defaultValue: 3.14
			fieldWidth: 50
			max: 5
			decimals: 2
		}

		PercentField
		{
			info: qsTr("This is the number that will be used in the operation")

			name: "my_percent"
			label: qsTr("Input a percentage")
		}

		CIField
		{
			info: qsTr("This is the number that will be used in the operation")

			name: "my_ci"
			label: qsTr("Input a confidence interval")
		}

		TextField
		{
			info: qsTr("This is a text field that can be used to input any text")

			name: "my_text"
			label: qsTr("Input some text")

			// We can add some extra control parameters
			fieldWidth: 200
			defaultValue: qsTr("Hello world!")
		}
	}

	Section
	{
		title: qsTr("Advanced controls")


		Group
		{
			title: qsTr("Subordinate menus")

			CheckBox
			{

				name: "my_advanced_tick_mark"
				label: qsTr("Activate advanced options?")

				// We can add some extra control parameters
				checked: false // Default value

				// The tic mark below is only available if the above tick mark is checked
				CheckBox
				{ 
					name: "my_subordinate_tick_mark"
					label: qsTr("Subordinate tick mark")
					checked: false // Default value
				}
			}
		}
	}

}
