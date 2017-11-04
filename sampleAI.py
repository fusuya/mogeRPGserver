# ※ もげRPGサーバーから起動する場合は -u オプションを指定して出力バッ
#    ファリングを切る必要がある。
#        python3 -u sampleAI.py

import sys
import json
import random

def map_mode(message):
    choice = random.sample(["UP", "DOWN", "RIGHT", "LEFT", "HEAL"], 1)[0]
    print(choice)

def battle_mode(message):
    print("SWING")

def equip_mode(message):
    print("YES")

def levelup_mode(message):
    print("HP")

def main():
    print("PythonサンプルAI")
    while True:
        line = sys.stdin.readline()
        if line == "":
            break
        message = json.loads(line)
        if "map" in message:
            map_mode(message)
        elif "battle" in message:
            battle_mode(message)
        elif "equip" in message:
            equip_mode(message)
        elif "levelup" in message:
            levelup_mode(message)
        else:
            sys.exit("Unknown message type")

main()
