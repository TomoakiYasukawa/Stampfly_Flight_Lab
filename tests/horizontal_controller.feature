# --- front-matter:toml ---
model = "HorizontalControllerTest.slx"
[inputs]
Roll = "RollAngle"
Pitch = "PitchAngle"
VX = "VelocityX"
VY = "VelocityY"
PX = "PositionX"
PY = "PositionY"
Valid = "Valid"
Yaw = "Heading"
Height = "Height"
Saturation = "MotorSaturated"
[outputs]
SelectedRoll = "SelectedRoll"
SelectedPitch = "SelectedPitch"
State = "State"
Blend = "Blend"
IntegralX = "IntegralX"
IntegralY = "IntegralY"
# --- end front-matter ---

Feature: Saved horizontal controller behavior

Scenario: Invalid measurement preserves manual command
  Given inputs
    * Roll = const(0.2)
    * Pitch = const(-0.1)
    * VX = const(0)
    * VY = const(0)
    * PX = const(0)
    * PY = const(0)
    * Valid = const(0)
    * Yaw = const(0)
    * Height = const(0.5)
    * Saturation = const(0)
  When simulate for 2s in Normal mode
  Then outputs
    * ManualRoll: SelectedRoll == [0.199999 .. 0.200001]
    * ManualPitch: SelectedPitch == [-0.100001 .. -0.099999]
    * NoBlend: Blend == 0
    * NoIntegralX: IntegralX == 0
    * NoIntegralY: IntegralY == 0

Scenario: Healthy neutral input engages stopping position hold
  Given inputs
    * Roll = const(0)
    * Pitch = const(0)
    * VX = const(0)
    * VY = const(0)
    * PX = const(0)
    * PY = const(0)
    * Valid = const(1)
    * Yaw = const(0)
    * Height = const(0.5)
    * Saturation = const(0)
  When simulate for 2s in Normal mode
  Then outputs
    * HoldEngaged: State == 2 when t > 1s
    * FullAssist: Blend == 1 when t > 1s
    * NeutralRoll: SelectedRoll == [-0.000001 .. 0.000001]
    * NeutralPitch: SelectedPitch == [-0.000001 .. 0.000001]

Scenario: Forward movement changes pitch reference after engagement
  Given inputs
    * Roll = const(0)
    * Pitch = step(0 -> -0.3 @ 1s)
    * VX = const(0)
    * VY = const(0)
    * PX = const(0)
    * PY = const(0)
    * Valid = const(1)
    * Yaw = const(0)
    * Height = const(0.5)
    * Saturation = const(0)
  When simulate for 3s in Normal mode
  Then outputs
    * MoveState: State == 3 when t > 1.5s
    * ForwardPitch: SelectedPitch < -0.01 when t > 2s
    * AssistTiltBound: SelectedPitch == [-0.175 .. 0.175]

Scenario: Measurement loss resets PI and returns to manual
  Given inputs
    * Roll = const(0)
    * Pitch = const(0)
    * VX = const(0.2)
    * VY = const(-0.1)
    * PX = const(0)
    * PY = const(0)
    * Valid = step(1 -> 0 @ 1s)
    * Yaw = const(0)
    * Height = const(0.5)
    * Saturation = const(0)
  When simulate for 2s in Normal mode
  Then outputs
    * WaitForRecovery: State == 1 when t > 1.2s
    * ManualBlend: Blend == 0 when t > 1.2s
    * ResetIntegralX: IntegralX == 0 when t > 1.2s
    * ResetIntegralY: IntegralY == 0 when t > 1.2s
