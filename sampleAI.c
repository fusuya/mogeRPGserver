/*
  1. Janssonライブラリをインストール。
      sudo apt-get install libjansson-dev
  2. コンパイル。
      gcc -o sampleAI sampleAI.c -ljansson
 */
#include <stdio.h>
#include <stdlib.h>
#include <jansson.h>

#define BUF_SIZE 4096

void map_mode(json_t* message)
{
    const char* choices[] = {"UP", "DOWN", "RIGHT", "LEFT", "HEAL"};
    int nchoices = sizeof(choices)/sizeof(choices[0]);
    puts(choices[rand() % nchoices]);
}

void battle_mode(json_t* message)
{
    puts("SWING");
}

void equip_mode(json_t* message)
{
    puts("YES");
}

void levelup_mode(json_t* message)
{
    puts("HP");
}

int main()
{
    // 標準出力を行バッファリングにする。
    setvbuf(stdout, NULL, _IOLBF, 0);

    // 名を名乗る。
    printf("C言語サンプルAI\n");

    char line[BUF_SIZE];
    while (fgets(line, BUF_SIZE, stdin) != NULL) {
        json_t *message = json_loads(line, 0, NULL);

        if (!message || !json_is_object(message))
            abort();

        if (json_object_get(message, "map"))
            map_mode(message);
        else if (json_object_get(message, "battle"))
            battle_mode(message);
        else if (json_object_get(message, "equip"))
            equip_mode(message);
        else if (json_object_get(message, "levelup"))
            levelup_mode(message);
        else
            abort();

        json_decref(message);
    }
    return 0;
}
