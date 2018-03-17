#include <iostream>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include "mraa.hpp"

using namespace std;
using namespace mraa;

#define LEDPIN 14

int main(){

    cout << "Hello, Internet of Things!" << endl;

    Gpio pin(LEDPIN);
    pin.dir(DIR_OUT);

    for (int i = 0; i < 10; i++){
        cout << i << " " << flush;
        pin.write(0);
        sleep(1);
        pin.write(1);
        sleep(1);
    }

    cout << endl << "Bye." << endl; 

    return SUCCESS;
}