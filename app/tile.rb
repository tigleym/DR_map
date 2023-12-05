class Tile
  attr_reader :x, :y
  def initialize(x, y)
    @x = x
    @y = y
  end

  # Serialization
  def serialize
    {
        x: @x, y: @y,
        passable: @passable
    }

  end
  def inspect
      serialize.to_s
  end
  def to_s
      serialize.to_s
  end

  def x
    @x
  end

  def y
    @y
  end

  def passable
    @passable
  end

  def empty
    @passable = true
  end

  def wall
    @passable = false
  end

  def north
    @y+1
  end

  def east
    @x+1
  end
  def south
    @y-1
  end

  def west
    @x-1
  end
end
