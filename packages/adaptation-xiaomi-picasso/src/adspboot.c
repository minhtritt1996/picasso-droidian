#include <linux/module.h>
#include <linux/init.h>
#include <soc/qcom/subsystem_restart.h>

static void *adsp_h;

static int __init adspboot_init(void)
{
    pr_info("adspboot: calling subsystem_get(adsp)...\n");
    adsp_h = subsystem_get("adsp");
    pr_info("adspboot: subsystem_get(adsp) returned %p\n", adsp_h);
    if (IS_ERR(adsp_h)) {
        pr_err("adspboot: subsystem_get(adsp) failed: %ld\n", PTR_ERR(adsp_h));
        return PTR_ERR(adsp_h);
    }
    return 0;
}

static void __exit adspboot_exit(void)
{
    if (adsp_h && !IS_ERR(adsp_h)) {
        subsystem_put(adsp_h);
        pr_info("adspboot: released adsp\n");
    }
}

module_init(adspboot_init);
module_exit(adspboot_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("ADSP Boot Loader");
