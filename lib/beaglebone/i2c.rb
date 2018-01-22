module Beaglebone #:nodoc:
  module I2C

    I2C_SLAVE = 0x0703

    @i2cstatus = {}
    @i2cmutex = Mutex.new

    class << self
      attr_accessor :i2cstatus, :i2cmutex

      # I2C.setup(:I2C2)
      def setup(i2c)
        i2cdev = I2CS[i2c][:dev]
        i2c_fd = File.open(i2cdev, 'r+')
        set_i2c_status(i2c, :fd_i2c, i2c_fd)
        set_i2c_status(i2c, :mutex, Mutex.new)
      end

      # @example
      #  I2C.write(:I2C2, 0x1e, [0x00, 0b10010000].pack("C*") )
      #  where first byte of data is register?????
      def write(i2c, address, data)
        check_i2c_enabled(i2c)

        lock_i2c(i2c) do
          i2c_fd = get_i2c_status(i2c, :fd_i2c)

          #set the slave address to communicate with
          i2c_fd.ioctl(I2C_SLAVE, address)

          i2c_fd.syswrite(data)
        end
      end

      # @example
      #   # read 3 big endian signed shorts starting at register 0x03
      #   data = I2C.read(:I2C2, 0x1e, 6, [0x03].pack("C*"))
      #     x,z,y = raw.unpack("s>*")
      def read(i2c, address, bytes=1, register=nil)
        check_i2c_enabled(i2c)

        data = ''
        lock_i2c(i2c) do
          i2c_fd = get_i2c_status(i2c, :fd_i2c)

          #set the slave address to communicate with
          i2c_fd.ioctl(I2C_SLAVE, address)

          i2c_fd.syswrite(register) if register

          data = i2c_fd.sysread(bytes)
        end

        data
      end

      # @param i2c should be a symbol representing the I2C device
      def file(i2c)
        check_i2c_enabled(i2c)
        get_i2c_status(i2c, :fd_i2c)
      end

      # Disable all active I2C interfaces
      def cleanup
        #reset all i2cs we've used and unload the device tree
        i2cstatus.clone.keys.each { |i2c| disable(i2c)}
      end

      private

      # disable i2c pin
      def disable_i2c_pin(pin)
        Beaglebone::check_valid_pin(pin, :i2c)

        Beaglebone::delete_pin_status(pin)
      end

      # ensure valid i2c device
      def check_i2c_valid(i2c)
        raise ArgumentError, "Invalid i2c Specified #{i2c.to_s}" unless I2CS[i2c] && I2CS[i2c][:sda]
        i2cinfo = I2CS[i2c.to_sym]

        unless i2cinfo[:scl] && [nil,:i2c].include?(Beaglebone::get_pin_status(i2cinfo[:scl], :type))
          raise StandardError, "SCL Pin for #{i2c.to_s} in use"
        end

        unless i2cinfo[:sda] && [nil,:i2c].include?(Beaglebone::get_pin_status(i2cinfo[:sda], :type))
          raise StandardError, "SDA Pin for #{i2c.to_s} in use"
        end

      end

      # ensure i2c device is enabled
      def check_i2c_enabled(i2c)
        raise ArgumentError, "i2c not enabled #{i2c.to_s}" unless get_i2c_status(i2c)
      end

      # lock i2c device
      def lock_i2c(i2c)
        check_i2c_enabled(i2c)
        mutex = get_i2c_status(i2c, :mutex)

        mutex.synchronize do
          yield
        end
      end

      # i2c hash getter
      def get_i2c_status(i2c, key = nil)
        i2cmutex.synchronize do
          if key
            i2cstatus[i2c] ? i2cstatus[i2c][key] : nil
          else
            i2cstatus[i2c]
          end
        end
      end

      # i2c hash setter
      def set_i2c_status(i2c, key, value)
        i2cmutex.synchronize do
          i2cstatus[i2c]    ||= {}
          i2cstatus[i2c][key] = value
        end
      end

      # i2c hash delete
      def delete_i2c_status(i2c, key = nil)
        i2cmutex.synchronize do
          if key.nil?
            i2cstatus.delete(i2c)
          else
            i2cstatus[i2c].delete(key) if i2cstatus[i2c]
          end
        end
      end

    end
  end

  class I2CDevice
    #   i2c = I2CDevice.new(:I2C2)
    def initialize(i2c)
      @i2c = i2c
      I2C::setup(i2c)
    end

    # @example
    #  i2c.write(0x1e, [0x00, 0b10010000].pack("C*") )
    def write(address, data)
      I2C::write(@i2c, address, data)
    end

    def read(address, bytes=1, register=nil)
      I2C::read(@i2c, address, bytes, register)
    end

    # Return the file descriptor to the open I2C device
    def file
      I2C::file(@i2c)
    end
  end
end
