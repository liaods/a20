/* this file is generated, don't edit it yourself */

#include <common.h>
#include <asm/arch/dram.h>

static struct dram_para dram_para = {
	.clock = 480,
	.type = 3,
	.rank_num = 1,
	.density = 4096,
	.io_width = 16,
	.bus_width = 32,
	.cas = 9,
	.zq = 0x7a,
	.odt_en = 0,
	.size = 1024,
	.tpr0 = 0x42d899b7,
	.tpr1 = 0xa090,
	.tpr2 = 0x22a00,
	.tpr3 = 0x0,
	.tpr4 = 0x1,
	.tpr5 = 0x0,
	.emr1 = 0x4,
	.emr2 = 0x10,
	.emr3 = 0x0,
};

int sunxi_dram_init(void)
{
	return dramc_init(&dram_para);
}
