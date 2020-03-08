class Tile
  def initialize(x, y)
    @x = x
    @y = y
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
