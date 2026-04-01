#include <math.h>
#include <stdio.h>

int main() {
    printf("tgamma(2.0) = %f\n", tgamma(2.0));
    printf("tgammaf(2.0f) = %f\n", tgammaf(2.0f));
    printf("erf(1.0) = %f\n", erf(1.0));
    printf("erff(1.0f) = %f\n", erff(1.0f));
    printf("erfc(1.0) = %f\n", erfc(1.0));
    printf("erfcf(1.0f) = %f\n", erfcf(1.0f));
    return 0;
}