# libomptarget_runtime.a

This is the device side of the OpenMP target library. This .a will be linked with your OpenMP application and hosts the main function for the device. This main function (see `main.c`) infinitely loops waiting for host kernels. When the host starts an OpenMP application, the device will be reset and the main function will be called again.

OpenMP target device library interacts with the OpenMP target host library via software mailboxes (see `sw_mailbox.h`) implemented as ring buffers (see `struct ring_buf`). It is important that host and device share the same structure of the `struct ring_buf` that the host defines it in `libhero.so`.

Before receiving kernels, the main function will find the address of the `ring_buf`. For now the two scratchpad registers at `0x3000000` and `0x3000004` are used. The host side sets these registers in `hero_dev_init`.

Make this library with:
```bash
make archive_app
```

And build your hero app in the HERO repository at `apps/carfield/omp/helloworld`. Note you will need to define `CARFIELD_ROOT` with the root of the Carfield repository in order to find `libomptarget_runtime.a`.
