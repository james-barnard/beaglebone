# Beaglebone Ruby Library

**Table of Contents**
- [Overview](#overview)
- [Installation](#installation)
  - [Installing Ruby](#installing-ruby)
  - [Installing Beaglebone Gem](#installing-beaglebone-gem)
  - [Updating Beaglebone Gem](#updating-beaglebone-gem)
- [Usage](#usage)
  - [Ruby in Cloud9](#ruby-in-cloud9)
- [Pin Information](#pin-information)
  - [GPIO Pins](#gpio-pins)
  - [Analog Pins](#analog-pins)
  - [PWM Pins](#pwm-pins)
  - [UART Pins](#uart-pins)
  - [I2C Pins](#i2c-pins)
  - [SPI Pins](#spi-pins)
- [Source Code Reference](#source-code-reference)
- [Examples (Object Oriented)](#examples-object-oriented)
  - [GPIO](#gpio)
    - [GPIO Writing](#gpio-writing)
    - [GPIO Reading](#gpio-reading)
    - [LEDs](#leds)
    - [Edge Triggers](#edge-triggers)
    - [Edge Triggers in the Background](#edge-triggers-in-the-background)
    - [Shift Registers](#shift-registers)
  - [Analog Inputs](#analog-inputs)
    - [Reading](#reading)
    - [Waiting for Change](#waiting-for-change)
    - [Waiting for Change in the Background](#waiting-for-change-in-the-background)
    - [Waiting for Threshold](#waiting-for-threshold)
    - [Waiting for Threshold in the Background](#waiting-for-Threshold-in-the-background)
  - [PWM](#pwm)
  - [UART](#uart)
    - [UART Writing](#uart-writing)
    - [UART Reading](#uart-reading)
    - [UART Reading and Iterating](#uart-reading-and-iterating)
    - [UART Reading and Iterating in the Background](#uart-reading-and-iterating-in-the-background)
  - [I2C](#i2c)
    - [I2C Writing](#i2c-writing)
    - [I2C Reading](#i2c-reading)
    - [LSM303DLHC Example](#lsm303dlhc-example)
  - [SPI](#spi)
    - [SPI Data Transfer](#spi-data-transfer)
    - [MCP3008 Example](#mcp3008-example)
- [Examples (Procedural)](#examples-procedural)
- [License](#license)

## Overview
The purpose of this library is to provide easy access to all of the IO features of the Beaglebone in a highly flexible programming language (Ruby).  This gem includes object oriented methods as well as procedural methods, so those familiar with Bonescript, the Adafruit Python library, or Arduino programming will be familiar with the syntax.  This was developed and tested on a Beaglebone Black running the official Debian images.  The code will need to be executed as root in order to function properly and utilize all of the features of the Beaglebone.

## Installation
### Installing Ruby
Ruby and Rubygems are required to use this gem.  To install, simply run the command below.  This will install Ruby 1.9.3 which includes Rubygems.

```
sudo apt-get install ruby
```

### Installing Beaglebone Gem
Once Ruby is installed installed, install the gem by running the command below.

```
sudo gem install specific_install
sudo gem specific_install -l https://github.com/james-barnard/beaglebone.git
```

### Updating Beaglebone Gem
Once the gem is installed, you can update to the latest version by running the command below.  New versions may contain bug fixes and new features.

```
sudo gem specific_install -l https://github.com/james-barnard/beaglebone.git
```

## Usage
To use this gem, require it in the Ruby script.  An example follows

```ruby
#!/usr/bin/env ruby
require 'beaglebone'
include Beaglebone
```

### GPIO Pins
The beaglebone has a large number of GPIO pins.  These pins function at 3.3v.  Do not provide more than 3.3v to any GPIO pin or risk damaging the hardware.

There are built in _capes_ that have priority over the GPIO pins unless disabled.  These are for HDMI and the onboard eMMC.  It is documented [here](http://beagleboard.org/Support/bone101#headers-black).  It is possible to disable these _capes_ if you are not using them.

### Analog Pins
The beaglebone has 7 Analog inputs.  Documentation on these pins is available [here](http://beagleboard.org/Support/bone101#headers-analog).  These pins function at 1.8v.  Do not provide more than 1.8v to any Analog pin or risk damaging the hardware.  The header has pins available to provide a 1.8v for analog devices as well as a dedicated analog ground.

### PWM Pins
The beaglebone has 8 PWM pins.  Documentation on these pins is available [here](http://beagleboard.org/Support/bone101#headers-pwm).  These pins function at 3.3v.

Not all 8 pins may be used at the same time. You may use the following pins.

- P8_13 or P8_19
- P9_14 or P9_16
- P9_21 or P9_22
- P9_28 and P9_42

## Examples (Object Oriented)
These examples will show the various ways to interact with the Beaglebones IO hardware.  They will need to be executed as root in order to function correctly.

### GPIO
The GPIO pins on the Beaglebone run at **3.3v**.  Do not provide more than 3.3v to any GPIO pin or risk damaging the hardware.

GPIO pins have two modes, input and output.  These modes are represented by the symbols **:IN** and **:OUT**.

GPIO pins have internal pullup and pulldown resistors.  These modes are represented by the symbols **:PULLUP**, **:PULLDOWN**, and **:NONE**.

GPIO pins have an adjustable slew rate.  These modes are represented by the symbols **:FAST** and **:SLOW**

To initialize the pin **P9_11**, pass the symbol for that pin and the mode to the **GPIOPin** constructor.

```ruby
# Initialize pin P9_11 in INPUT mode
# This method takes 4 arguments
# pin: The pin to initialize
# mode: The GPIO mode, :IN or :OUT
# pullmode: (optional) The pull mode, :PULLUP, :PULLDOWN, or :NONE
# slewrate: (optional) The slew rate, :FAST or :SLOW
p9_11 = GPIOPin.new(:P9_11, :IN, :PULLUP, :FAST)

# Initialize pin P9_12 in OUTPUT mode
p9_12 = GPIOPin.new(:P9_12, :OUT)

# Change pin P9_12 to INPUT mode
p9_12.set_gpio_mode(:IN)

# Disable pin P9_12
p9_12.disable_gpio_pin

# Unassign to prevent re-use
p9_12 = nil
```

#### GPIO Writing
To set the state of a GPIO pin, the method **#digital_write** is used.  The states that can be set are **:HIGH** to provide 3.3v and **:LOW** to provide ground.

```ruby
# Initialize pin P9_12 in OUTPUT mode
p9_12 = GPIOPin.new(:P9_12, :OUT)

# Provide 3.3v on pin P9_12
p9_12.digital_write(:HIGH)

# Provide ground on pin P9_12
p9_12.digital_write(:LOW)
```

#### GPIO Reading
To read the current state of a GPIO pin, the method **#digital_read** is used.  It will return the symbol **:HIGH** or **:LOW** depending on the state of the pin.

```ruby
# Initialize pin P9_11 in INPUT mode
p9_11 = GPIOPin.new(:P9_11, :IN)

# Get the current state of P9_11
state = p9_11.digital_read => :LOW
```

## License
Copyright (c) 2014 Rob Mosher.  Distributed under the GPL-v3 License.  See [LICENSE](LICENSE) for more information.
