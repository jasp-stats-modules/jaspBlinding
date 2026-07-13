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
  info: qsTr("This example shows how to plot a curve.")

  Text
  {
      text: qsTr("This example shows how to plot a curve")
  }

	IntegerField
	{
		info: qsTr("The shape of the parabola is dynamically determined by this number")

		name: "a"                      // This will map to options$a in R
		label: qsTr("Type a number")   // qsTr allows for future translations

		// We can add some extra control parameters
		min: -10
		defaultValue: 1
		fieldWidth: 50
		max: 10
	}

}
