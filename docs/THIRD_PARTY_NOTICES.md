# Source notices

`code/+official/controllerStep.m`, `pidStep.m`, `filterStep.m`, `sensorStep.m`,
`kalmanStep.m` and the controller reference are translations/extracts of the
M5Stack / Kouhei Ito 2024 implementation. They carry the terms of
`official_sources/M5StampFly/LICENSE` (MIT); preserve that license with copies.

`code/+official/madgwickStep.m` is a translation of the bundled
`lib/MdgwickAHRS/MadgwickAHRS.cpp`. Its source header attributes SOH Madgwick
(2011–2012) and states GNU General Public Licence unless an alternative license
is provided. The original header and source are retained under
`official_sources/M5StampFly/lib/MdgwickAHRS`. The repository-wide MIT license
does not erase that notice.

Bosch BMI270 and ST VL53LX sources retain their own notices in their original
files and the copied `third_party` directory. Logger infrastructure was copied
from the user's `stampfly_imu_monitor` project.
