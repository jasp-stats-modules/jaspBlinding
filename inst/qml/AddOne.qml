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

  info: qsTr("This analysis just adds one to the input. \
  It's purpose is to show an easy example of how a manual input gets processed \
  by the backend, and returned.
  \\
  \\
  From the technical point of view, the most challenging part of JASP module \
  development is the communication between the QML interface and the R backend.
  \\
  \\
  Playing with the current JASP analysis while simultaneously inspecting the R \
  code in the files `./inst/qml/AddOne.qml` and `./R/examples.R` is a good \
  way to learn how this communication works.
  ")

  Text
  {
      text: qsTr("This example shows how to manually introduce an input and perform a simple operation on it")
  }

	IntegerField
	{
		info: qsTr("This is the number that will be used in the operation")

		name: "my_number"              // This will map to options$my_number in R
		label: qsTr("Type a number")   // qsTr allows for future translations

		// We can add some extra control parameters
		min: 1
		defaultValue: 10
		fieldWidth: 50
		max: 1000
	}

}
