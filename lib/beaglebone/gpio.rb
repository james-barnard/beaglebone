# == gpio.rb
# This file contains the GPIO methods

module Beaglebone #:nodoc:
  module GPIO
    class << self
      MODES = [ :IN, :OUT ]
      STATES = { :HIGH => 1, :LOW => 0 }
      PULLMODES = [ :PULLUP, :PULLDOWN, :NONE ]
      GPIO_USERSPACE = '/sys/class/gpio'

      def pin_mode(pin, mode, pullmode = nil, slewrate = nil)
        puts "pin_mode: #{pin}: #{mode}"
        validate_mode!(mode)
        validate_pin!(pin)

        pininfo = PINS[pin]

        if mode == :IN and pullmode != :PULLUP and ( pininfo[:mmc] or pin == :P9_15 )
          raise ArgumentError, "Invalid Pull mode specified for pin: #{pin} (#{pullmode})"
        end

        unless Beaglebone::get_pin_status(pin, :type) == :gpio
          configure_pin(pin, mode, pullmode, slewrate, false)
          export_pin(pininfo)

          raise StandardError, "GPIO was unable to initalize pin: #{pin.to_s}" unless enabled?(pin)
        end

        check_direction!(pin, mode)

        Beaglebone::set_pin_status(pin, :mode, mode)
      end

      def validate_pin!(pin)
        raise ArgumentError, "No such PIN: #{pin.to_s}" unless PINS[pin]
        raise ArgumentError, "Not a GPIO pin: #{pin.to_s}" unless PINS[pin][:gpio]
      end

      def check_direction!(pin, mode)
        dir = read_gpio_direction(pin)
        raise StandardError, "GPIO was unable to set mode: #{pin.to_s} to #{mode.to_s} (#{dir})" if mode != dir
      end

      def export_pin(pininfo)
        begin
          File.open("#{GPIO_USERSPACE}/export", 'w') { |f| f.write pininfo[:gpio] }
        rescue
          #
        end
      end

      def unexport_pin(pin)
        begin
          File.open("#{GPIO_USERSPACE}/unexport", 'w') { |f| f.write(pininfo[:gpio]) }
        rescue
          #
        end
      end

      def digital_write(pin, state)
        validate_state(state)
        check_gpio_enabled(pin)

        raise StandardError, "PIN not in GPIO OUT mode: #{pin}" unless get_gpio_mode(pin) == :OUT

        fd = get_value_fd(pin)
        fd.write STATES[state.to_sym].to_s
        fd.flush
        Beaglebone::set_pin_status(pin, :state, state)
      end

      def digital_read(pin)
        check_gpio_enabled(pin)

        raise StandardError, "PIN not in GPIO IN mode: #{pin}" unless get_gpio_mode(pin) == :IN

        fd = get_value_fd(pin)
        fd.rewind
        value = fd.read.to_s.strip
        state = STATES.key(value.to_i)

        Beaglebone::set_pin_status(pin, :state, state)
      end

      def cleanup
        get_gpio_pins.each { |x| disable_gpio_pin(x) }
      end

      def enabled?(pin)
        return true if Beaglebone::get_pin_status(pin, :type) == :gpio
        puts 'get_pin_status returned false'

        puts "gpio_directory: #{gpio_directory(pin)}"
        if Dir.exists?(gpio_directory(pin))
          Beaglebone::set_pin_status(pin, :type, :gpio)
          return true
        end

        false
      end

      def get_gpio_state(pin)
        check_gpio_enabled(pin)

        state = Beaglebone::get_pin_status(pin, :state)
        return state if state

        digital_read(pin)
      end

      def get_gpio_mode(pin)
        check_gpio_enabled(pin)

        mode = Beaglebone::get_pin_status(pin, :mode)
        return mode if mode

        read_gpio_direction(pin)
      end

      def set_gpio_mode(pin, mode)
        validate_mode!(mode)
        check_gpio_enabled(pin)

        File.open("#{gpio_directory(pin)}/direction", 'w') { |f| f.write mode.to_s.downcase }
        Beaglebone::set_pin_status(pin, :mode, mode)
      end

      def get_gpio_pins
        Beaglebone.pinstatus.clone.select { |x,y| x if y[:type] == :gpio && !PINS[x][:led] }.keys
      end

      def disable_gpio_pin(pin)
        pininfo = PINS[pin]

        close_value_fd(pin)
        unexport_pin(pininfo[:gpio])
        Beaglebone::delete_pin_status(pin)

        raise StandardError, "GPIO was unable to uninitalize pin: #{pin.to_s}" if enabled?(pin)
      end

      private
      def gpio_directory(pin)
        "#{GPIO_USERSPACE}/gpio#{PINS[pin][:gpio]}"
      end

      #read gpio direction file
      def read_gpio_direction(pin)
        check_gpio_enabled(pin)

        Beaglebone::set_pin_status(pin, :mode, File.open("#{gpio_directory(pin)}/direction", 'r').read.to_s.strip.to_sym.upcase)
      end

      #return the open value fd, or open if needed
      def get_value_fd(pin)
        check_gpio_enabled(pin)

        fd = Beaglebone::get_pin_status(pin, :fd_value)
        return fd if fd

        fd = File.open("#{gpio_directory(pin)}/value", 'w+')

        Beaglebone::set_pin_status(pin, :fd_value, fd)
      end

      #close value fd if open
      def close_value_fd(pin)
        fd = Beaglebone::get_pin_status(pin, :fd_value)
        fd.close if fd
        Beaglebone::delete_pin_status(pin, :fd_value)
      end

      #ensure state is valid
      def validate_state(state)
        #check to see if mode is valid
        state = state.to_sym
        raise ArgumentError, "No such state: #{state.to_s}" unless STATES.include?(state)
      end

      #ensure mode is valid
      def validate_mode!(mode)
        mode = mode.to_sym
        raise ArgumentError, "No such mode: #{mode.to_s}" unless MODES.include?(mode)
      end

      def check_gpio_enabled(pin)
        raise StandardError, "PIN not GPIO enabled: #{pin}" unless enabled?(pin)
      end

      def config_pin_mode(mode)
        mode == :IN ? 'in-' : 'out'
      end

      def configure_pin(pin, mode, pullmode, slewrate, force = false)
        raise "config-pin failed: #{$?}" unless system("config-pin", pin.to_s, config_pin_mode(mode))
      end
    end
  end

  class GPIOPin

    # Initialize a GPIO pin
    # Return's a GPIOPin object, setting the pin mode on initialization
    #
    # @param mode should specify the mode of the pin, either :IN or :OUT
    #
    # @return [GPIOPin]
    #
    # @example
    #   p9_12 = GPIOPin.new(:P9_12, :OUT)
    #   p9_11 = GPIOPin.new(:P9_11, :IN)
    def initialize(pin, mode, pullmode = nil, slewrate = nil)
      @pin = pin

      GPIO::pin_mode(@pin, mode, pullmode, slewrate)
    end

    def digital_write(state)
      GPIO::digital_write(@pin, state)
    end

    def digital_read
      GPIO::digital_read(@pin)
    end

    def get_gpio_state
      GPIO::get_gpio_state(@pin)
    end

    def get_gpio_mode
      GPIO::get_gpio_mode(@pin)
    end

    def set_gpio_mode(mode)
      GPIO::set_gpio_mode(@pin, mode)
    end

    def disable_gpio_pin
      GPIO::disable_gpio_pin(@pin)
    end

  end
end
