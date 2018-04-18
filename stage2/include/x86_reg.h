#ifndef _X86_REG_H
#define _X86_REG_H

struct x86_reg {
    union {
        uint16_t ax;
        struct {
            uint8_t al;
            uint8_t ah;
        };
    };

    union {
        uint16_t bx;
        struct {
            uint8_t bl;
            uint8_t bh;
        };
    };

    union {
        uint16_t cx;
        struct {
            uint8_t cl;
            uint8_t ch;
        };
    };

    union {
        uint16_t dx;
        struct {
            uint8_t dl;
            uint8_t dh;
        };
    };

    uint16_t si;
    uint16_t di;
} __attribute__((packed));


void x86int(struct x86_reg *reg, uint8_t vec);

#endif /* _X86_REG_H */
