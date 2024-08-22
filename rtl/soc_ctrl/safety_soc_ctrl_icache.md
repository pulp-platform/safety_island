## Summary

| Name                                                                       | Offset   |   Length | Description                            |
|:---------------------------------------------------------------------------|:---------|---------:|:---------------------------------------|
| safety_soc_ctrl_icache.[`bootaddr`](#bootaddr)                             | 0x0      |        4 | Core Boot Address                      |
| safety_soc_ctrl_icache.[`fetchen`](#fetchen)                               | 0x4      |        4 | Core Fetch Enable                      |
| safety_soc_ctrl_icache.[`corestatus`](#corestatus)                         | 0x8      |        4 | Core Return Status (return value, EOC) |
| safety_soc_ctrl_icache.[`bootmode`](#bootmode)                             | 0xc      |        4 | Core Boot Mode                         |
| safety_soc_ctrl_icache.[`icache_enable_prefetch`](#icache_enable_prefetch) | 0x10     |        4 | Enable iCache prefetching              |
| safety_soc_ctrl_icache.[`icache_flush`](#icache_flush)                     | 0x14     |        4 | Flush iCache                           |
| safety_soc_ctrl_icache.[`icache_perfctr_ctrl`](#icache_perfctr_ctrl)       | 0x18     |        4 | iCache Performance Counter Control     |
| safety_soc_ctrl_icache.[`counters_0`](#counters)                           | 0x1c     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_1`](#counters)                           | 0x20     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_2`](#counters)                           | 0x24     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_3`](#counters)                           | 0x28     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_4`](#counters)                           | 0x2c     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_5`](#counters)                           | 0x30     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_6`](#counters)                           | 0x34     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_7`](#counters)                           | 0x38     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_8`](#counters)                           | 0x3c     |        4 | Performance counters                   |

## bootaddr
Core Boot Address
- Offset: `0x0`
- Reset default: `0x1a000000`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "bootaddr", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |   Reset    | Name     | Description   |
|:------:|:------:|:----------:|:---------|:--------------|
|  31:0  |   rw   | 0x1a000000 | bootaddr | Boot Address  |

## fetchen
Core Fetch Enable
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "fetchen", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 90}}
```

|  Bits  |  Type  |  Reset  | Name    | Description   |
|:------:|:------:|:-------:|:--------|:--------------|
|  31:1  |        |         |         | Reserved      |
|   0    |   rw   |   0x0   | fetchen | Fetch Enable  |

## corestatus
Core Return Status (return value, EOC)
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "core_status", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name        | Description                                             |
|:------:|:------:|:-------:|:------------|:--------------------------------------------------------|
|  31:0  |   rw   |   0x0   | core_status | Core Return Status (EOC(bit[31]) and status(bit[30:0])) |

## bootmode
Core Boot Mode
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "bootmode", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 100}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:2  |        |         |          | Reserved      |
|  1:0   |   rw   |   0x0   | bootmode | Boot Mode     |

## icache_enable_prefetch
Enable iCache prefetching
- Offset: `0x10`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "prefetch_enable", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 170}}
```

|  Bits  |  Type  |  Reset  | Name            | Description        |
|:------:|:------:|:-------:|:----------------|:-------------------|
|  31:1  |        |         |                 | Reserved           |
|   0    |   rw   |   0x1   | prefetch_enable | Enable prefetching |

## icache_flush
Flush iCache
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "flush", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:1  |        |         |        | Reserved      |
|   0    |   rw   |   0x0   | flush  | Flush         |

## icache_perfctr_ctrl
iCache Performance Counter Control
- Offset: `0x18`
- Reset default: `0x1`
- Reset mask: `0x10001`

### Fields

```wavejson
{"reg": [{"name": "enable", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 15}, {"name": "clear_all", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 15}], "config": {"lanes": 1, "fontsize": 10, "vspace": 110}}
```

|  Bits  |  Type  |  Reset  | Name      | Description                    |
|:------:|:------:|:-------:|:----------|:-------------------------------|
| 31:17  |        |         |           | Reserved                       |
|   16   |   rw   |   0x0   | clear_all | Clear all performance counters |
|  15:1  |        |         |           | Reserved                       |
|   0    |   rw   |   0x1   | enable    | Enable performance counters    |

## counters
Performance counters
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Instances

| Name       | Offset   |
|:-----------|:---------|
| counters_0 | 0x1c     |
| counters_1 | 0x20     |
| counters_2 | 0x24     |
| counters_3 | 0x28     |
| counters_4 | 0x2c     |
| counters_5 | 0x30     |
| counters_6 | 0x34     |
| counters_7 | 0x38     |
| counters_8 | 0x3c     |


### Fields

```wavejson
{"reg": [{"name": "counter", "bits": 32, "attr": ["rw0c"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name    | Description   |
|:------:|:------:|:-------:|:--------|:--------------|
|  31:0  |  rw0c  |   0x0   | counter |               |

## Summary

| Name                                                                       | Offset   |   Length | Description                            |
|:---------------------------------------------------------------------------|:---------|---------:|:---------------------------------------|
| safety_soc_ctrl_icache.[`bootaddr`](#bootaddr)                             | 0x0      |        4 | Core Boot Address                      |
| safety_soc_ctrl_icache.[`fetchen`](#fetchen)                               | 0x4      |        4 | Core Fetch Enable                      |
| safety_soc_ctrl_icache.[`corestatus`](#corestatus)                         | 0x8      |        4 | Core Return Status (return value, EOC) |
| safety_soc_ctrl_icache.[`bootmode`](#bootmode)                             | 0xc      |        4 | Core Boot Mode                         |
| safety_soc_ctrl_icache.[`icache_enable_prefetch`](#icache_enable_prefetch) | 0x10     |        4 | Enable iCache prefetching              |
| safety_soc_ctrl_icache.[`icache_flush`](#icache_flush)                     | 0x14     |        4 | Flush iCache                           |
| safety_soc_ctrl_icache.[`icache_perfctr_ctrl`](#icache_perfctr_ctrl)       | 0x18     |        4 | iCache Performance Counter Control     |
| safety_soc_ctrl_icache.[`counters_0`](#counters)                           | 0x1c     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_1`](#counters)                           | 0x20     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_2`](#counters)                           | 0x24     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_3`](#counters)                           | 0x28     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_4`](#counters)                           | 0x2c     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_5`](#counters)                           | 0x30     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_6`](#counters)                           | 0x34     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_7`](#counters)                           | 0x38     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_8`](#counters)                           | 0x3c     |        4 | Performance counters                   |

## bootaddr
Core Boot Address
- Offset: `0x0`
- Reset default: `0x1a000000`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "bootaddr", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |   Reset    | Name     | Description   |
|:------:|:------:|:----------:|:---------|:--------------|
|  31:0  |   rw   | 0x1a000000 | bootaddr | Boot Address  |

## fetchen
Core Fetch Enable
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "fetchen", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 90}}
```

|  Bits  |  Type  |  Reset  | Name    | Description   |
|:------:|:------:|:-------:|:--------|:--------------|
|  31:1  |        |         |         | Reserved      |
|   0    |   rw   |   0x0   | fetchen | Fetch Enable  |

## corestatus
Core Return Status (return value, EOC)
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "core_status", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name        | Description                                             |
|:------:|:------:|:-------:|:------------|:--------------------------------------------------------|
|  31:0  |   rw   |   0x0   | core_status | Core Return Status (EOC(bit[31]) and status(bit[30:0])) |

## bootmode
Core Boot Mode
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "bootmode", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 100}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:2  |        |         |          | Reserved      |
|  1:0   |   rw   |   0x0   | bootmode | Boot Mode     |

## icache_enable_prefetch
Enable iCache prefetching
- Offset: `0x10`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "prefetch_enable", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 170}}
```

|  Bits  |  Type  |  Reset  | Name            | Description        |
|:------:|:------:|:-------:|:----------------|:-------------------|
|  31:1  |        |         |                 | Reserved           |
|   0    |   rw   |   0x1   | prefetch_enable | Enable prefetching |

## icache_flush
Flush iCache
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "flush", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:1  |        |         |        | Reserved      |
|   0    |   rw   |   0x0   | flush  | Flush         |

## icache_perfctr_ctrl
iCache Performance Counter Control
- Offset: `0x18`
- Reset default: `0x1`
- Reset mask: `0x10001`

### Fields

```wavejson
{"reg": [{"name": "enable", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 15}, {"name": "clear_all", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 15}], "config": {"lanes": 1, "fontsize": 10, "vspace": 110}}
```

|  Bits  |  Type  |  Reset  | Name      | Description                    |
|:------:|:------:|:-------:|:----------|:-------------------------------|
| 31:17  |        |         |           | Reserved                       |
|   16   |   rw   |   0x0   | clear_all | Clear all performance counters |
|  15:1  |        |         |           | Reserved                       |
|   0    |   rw   |   0x1   | enable    | Enable performance counters    |

## counters
Performance counters
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Instances

| Name       | Offset   |
|:-----------|:---------|
| counters_0 | 0x1c     |
| counters_1 | 0x20     |
| counters_2 | 0x24     |
| counters_3 | 0x28     |
| counters_4 | 0x2c     |
| counters_5 | 0x30     |
| counters_6 | 0x34     |
| counters_7 | 0x38     |
| counters_8 | 0x3c     |


### Fields

```wavejson
{"reg": [{"name": "counter", "bits": 32, "attr": ["rw0c"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name    | Description   |
|:------:|:------:|:-------:|:--------|:--------------|
|  31:0  |  rw0c  |   0x0   | counter |               |

## Summary

| Name                                                                       | Offset   |   Length | Description                            |
|:---------------------------------------------------------------------------|:---------|---------:|:---------------------------------------|
| safety_soc_ctrl_icache.[`bootaddr`](#bootaddr)                             | 0x0      |        4 | Core Boot Address                      |
| safety_soc_ctrl_icache.[`fetchen`](#fetchen)                               | 0x4      |        4 | Core Fetch Enable                      |
| safety_soc_ctrl_icache.[`corestatus`](#corestatus)                         | 0x8      |        4 | Core Return Status (return value, EOC) |
| safety_soc_ctrl_icache.[`bootmode`](#bootmode)                             | 0xc      |        4 | Core Boot Mode                         |
| safety_soc_ctrl_icache.[`icache_enable_prefetch`](#icache_enable_prefetch) | 0x10     |        4 | Enable iCache prefetching              |
| safety_soc_ctrl_icache.[`icache_flush`](#icache_flush)                     | 0x14     |        4 | Flush iCache                           |
| safety_soc_ctrl_icache.[`icache_perfctr_ctrl`](#icache_perfctr_ctrl)       | 0x18     |        4 | iCache Performance Counter Control     |
| safety_soc_ctrl_icache.[`counters_0`](#counters)                           | 0x1c     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_1`](#counters)                           | 0x20     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_2`](#counters)                           | 0x24     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_3`](#counters)                           | 0x28     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_4`](#counters)                           | 0x2c     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_5`](#counters)                           | 0x30     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_6`](#counters)                           | 0x34     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_7`](#counters)                           | 0x38     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_8`](#counters)                           | 0x3c     |        4 | Performance counters                   |

## bootaddr
Core Boot Address
- Offset: `0x0`
- Reset default: `0x1a000000`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "bootaddr", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |   Reset    | Name     | Description   |
|:------:|:------:|:----------:|:---------|:--------------|
|  31:0  |   rw   | 0x1a000000 | bootaddr | Boot Address  |

## fetchen
Core Fetch Enable
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "fetchen", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 90}}
```

|  Bits  |  Type  |  Reset  | Name    | Description   |
|:------:|:------:|:-------:|:--------|:--------------|
|  31:1  |        |         |         | Reserved      |
|   0    |   rw   |   0x0   | fetchen | Fetch Enable  |

## corestatus
Core Return Status (return value, EOC)
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "core_status", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name        | Description                                             |
|:------:|:------:|:-------:|:------------|:--------------------------------------------------------|
|  31:0  |   rw   |   0x0   | core_status | Core Return Status (EOC(bit[31]) and status(bit[30:0])) |

## bootmode
Core Boot Mode
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "bootmode", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 100}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:2  |        |         |          | Reserved      |
|  1:0   |   rw   |   0x0   | bootmode | Boot Mode     |

## icache_enable_prefetch
Enable iCache prefetching
- Offset: `0x10`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "prefetch_enable", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 170}}
```

|  Bits  |  Type  |  Reset  | Name            | Description        |
|:------:|:------:|:-------:|:----------------|:-------------------|
|  31:1  |        |         |                 | Reserved           |
|   0    |   rw   |   0x1   | prefetch_enable | Enable prefetching |

## icache_flush
Flush iCache
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "flush", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:1  |        |         |        | Reserved      |
|   0    |   rw   |   0x0   | flush  | Flush         |

## icache_perfctr_ctrl
iCache Performance Counter Control
- Offset: `0x18`
- Reset default: `0x1`
- Reset mask: `0x10001`

### Fields

```wavejson
{"reg": [{"name": "enable", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 15}, {"name": "clear_all", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 15}], "config": {"lanes": 1, "fontsize": 10, "vspace": 110}}
```

|  Bits  |  Type  |  Reset  | Name      | Description                    |
|:------:|:------:|:-------:|:----------|:-------------------------------|
| 31:17  |        |         |           | Reserved                       |
|   16   |   rw   |   0x0   | clear_all | Clear all performance counters |
|  15:1  |        |         |           | Reserved                       |
|   0    |   rw   |   0x1   | enable    | Enable performance counters    |

## counters
Performance counters
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Instances

| Name       | Offset   |
|:-----------|:---------|
| counters_0 | 0x1c     |
| counters_1 | 0x20     |
| counters_2 | 0x24     |
| counters_3 | 0x28     |
| counters_4 | 0x2c     |
| counters_5 | 0x30     |
| counters_6 | 0x34     |
| counters_7 | 0x38     |
| counters_8 | 0x3c     |


### Fields

```wavejson
{"reg": [{"name": "counter", "bits": 32, "attr": ["rw0c"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name    | Description   |
|:------:|:------:|:-------:|:--------|:--------------|
|  31:0  |  rw0c  |   0x0   | counter |               |

## Summary

| Name                                                                       | Offset   |   Length | Description                            |
|:---------------------------------------------------------------------------|:---------|---------:|:---------------------------------------|
| safety_soc_ctrl_icache.[`bootaddr`](#bootaddr)                             | 0x0      |        4 | Core Boot Address                      |
| safety_soc_ctrl_icache.[`fetchen`](#fetchen)                               | 0x4      |        4 | Core Fetch Enable                      |
| safety_soc_ctrl_icache.[`corestatus`](#corestatus)                         | 0x8      |        4 | Core Return Status (return value, EOC) |
| safety_soc_ctrl_icache.[`bootmode`](#bootmode)                             | 0xc      |        4 | Core Boot Mode                         |
| safety_soc_ctrl_icache.[`icache_enable_prefetch`](#icache_enable_prefetch) | 0x10     |        4 | Enable iCache prefetching              |
| safety_soc_ctrl_icache.[`icache_flush`](#icache_flush)                     | 0x14     |        4 | Flush iCache                           |
| safety_soc_ctrl_icache.[`icache_perfctr_ctrl`](#icache_perfctr_ctrl)       | 0x18     |        4 | iCache Performance Counter Control     |
| safety_soc_ctrl_icache.[`counters_0`](#counters)                           | 0x1c     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_1`](#counters)                           | 0x20     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_2`](#counters)                           | 0x24     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_3`](#counters)                           | 0x28     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_4`](#counters)                           | 0x2c     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_5`](#counters)                           | 0x30     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_6`](#counters)                           | 0x34     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_7`](#counters)                           | 0x38     |        4 | Performance counters                   |
| safety_soc_ctrl_icache.[`counters_8`](#counters)                           | 0x3c     |        4 | Performance counters                   |

## bootaddr
Core Boot Address
- Offset: `0x0`
- Reset default: `0x1a000000`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "bootaddr", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |   Reset    | Name     | Description   |
|:------:|:------:|:----------:|:---------|:--------------|
|  31:0  |   rw   | 0x1a000000 | bootaddr | Boot Address  |

## fetchen
Core Fetch Enable
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "fetchen", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 90}}
```

|  Bits  |  Type  |  Reset  | Name    | Description   |
|:------:|:------:|:-------:|:--------|:--------------|
|  31:1  |        |         |         | Reserved      |
|   0    |   rw   |   0x0   | fetchen | Fetch Enable  |

## corestatus
Core Return Status (return value, EOC)
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "core_status", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name        | Description                                             |
|:------:|:------:|:-------:|:------------|:--------------------------------------------------------|
|  31:0  |   rw   |   0x0   | core_status | Core Return Status (EOC(bit[31]) and status(bit[30:0])) |

## bootmode
Core Boot Mode
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "bootmode", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 100}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:2  |        |         |          | Reserved      |
|  1:0   |   rw   |   0x0   | bootmode | Boot Mode     |

## icache_enable_prefetch
Enable iCache prefetching
- Offset: `0x10`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "prefetch_enable", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 170}}
```

|  Bits  |  Type  |  Reset  | Name            | Description        |
|:------:|:------:|:-------:|:----------------|:-------------------|
|  31:1  |        |         |                 | Reserved           |
|   0    |   rw   |   0x1   | prefetch_enable | Enable prefetching |

## icache_flush
Flush iCache
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "flush", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:1  |        |         |        | Reserved      |
|   0    |   rw   |   0x0   | flush  | Flush         |

## icache_perfctr_ctrl
iCache Performance Counter Control
- Offset: `0x18`
- Reset default: `0x1`
- Reset mask: `0x10001`

### Fields

```wavejson
{"reg": [{"name": "enable", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 15}, {"name": "clear_all", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 15}], "config": {"lanes": 1, "fontsize": 10, "vspace": 110}}
```

|  Bits  |  Type  |  Reset  | Name      | Description                    |
|:------:|:------:|:-------:|:----------|:-------------------------------|
| 31:17  |        |         |           | Reserved                       |
|   16   |   rw   |   0x0   | clear_all | Clear all performance counters |
|  15:1  |        |         |           | Reserved                       |
|   0    |   rw   |   0x1   | enable    | Enable performance counters    |

## counters
Performance counters
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Instances

| Name       | Offset   |
|:-----------|:---------|
| counters_0 | 0x1c     |
| counters_1 | 0x20     |
| counters_2 | 0x24     |
| counters_3 | 0x28     |
| counters_4 | 0x2c     |
| counters_5 | 0x30     |
| counters_6 | 0x34     |
| counters_7 | 0x38     |
| counters_8 | 0x3c     |


### Fields

```wavejson
{"reg": [{"name": "counter", "bits": 32, "attr": ["rw0c"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name    | Description   |
|:------:|:------:|:-------:|:--------|:--------------|
|  31:0  |  rw0c  |   0x0   | counter |               |

