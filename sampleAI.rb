# mogeRPGserver.exe --ai "ruby sampleAI.rb"

def map
    ["UP", "DOWN", "RIGHT", "LEFT", "HEAL"][rand(5)]
end
def battle
    "SWING"
end
def equip
    "YES"
end
def levelup
    "HP"
end
# main
STDOUT.sync = true
puts "RubyサンプルAI"
while line = gets
    if line =~ /"map"/
        output = map()
    elsif line =~ /"battle"/
        output = battle()
    elsif line =~ /"equip"/
        output = equip()
    elsif line =~ /"levelup"/
        output = levelup()
    elsif line =~ /"damage-info"/
        next
    else
        output = nil
    end
    if !output.nil?
        puts output
    end
end
