/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * SCMI Message Protocol driver header
 * @modified by Alessio Ferri for barebone usage inside pulp platform RISC-V core
 *
 * Copyright (C) 2018 ARM Ltd.
 */

#ifndef _SCMI_PROTOCOL_H
#define _SCMI_PROTOCOL_H


#define SCMI_MAX_STR_SIZE	16
#define SCMI_MAX_NUM_RATES	16

#include <stdint.h>

#define u8  uint8_t
#define s8  int8_t
#define u16 uint16_t
#define s16 int16_t
#define u32 uint32_t
#define s32 int32_t
#define u64 uint64_t
#define s64 int64_t

#define bool int

/**
 * struct scmi_revision_info - version information structure
 *
 * @major_ver: Major ABI version. Change here implies risk of backward
 *	compatibility break.
 * @minor_ver: Minor ABI version. Change here implies new feature addition,
 *	or compatible change in ABI.
 * @num_protocols: Number of protocols that are implemented, excluding the
 *	base protocol.
 * @num_agents: Number of agents in the system.
 * @impl_ver: A vendor-specific implementation version.
 * @vendor_id: A vendor identifier(Null terminated ASCII string)
 * @sub_vendor_id: A sub-vendor identifier(Null terminated ASCII string)
 */
struct scmi_revision_info {
	u16 major_ver;
	u16 minor_ver;
	u8 num_protocols;
	u8 num_agents;
	u32 impl_ver;
	char vendor_id[SCMI_MAX_STR_SIZE];
	char sub_vendor_id[SCMI_MAX_STR_SIZE];
};

typedef struct scmi_revision_info scmi_revision_info_t;

struct scmi_clock_info {
	char name[SCMI_MAX_STR_SIZE];
	bool rate_discrete;
	union {
		struct {
			int num_rates;
			u64 rates[SCMI_MAX_NUM_RATES];
		} list;
		struct {
			u64 min_rate;
			u64 max_rate;
			u64 step_size;
		} range;
	};
};

struct scmi_message;

/**
 * struct scmi_clk_ops - represents the various operations provided
 *	by SCMI Clock Protocol
 *
 * @count_get: get the count of clocks provided by SCMI
 * @info_get: get the information of the specified clock
 * @rate_get: request the current clock rate of a clock
 * @rate_set: set the clock rate of a clock
 * @enable: enables the specified clock
 * @disable: disables the specified clock
 */
struct scmi_clk_ops {
	int (*count_get)(const struct scmi_message *message);

	const struct scmi_clock_info *(*info_get)
		(const struct scmi_message *message, u32 clk_id);
	int (*rate_get)(const struct scmi_message *message, u32 clk_id,
			u64 *rate);
	int (*rate_set)(const struct scmi_message *message, u32 clk_id,
			u64 rate);
	int (*enable)(const struct scmi_message *message, u32 clk_id);
	int (*disable)(const struct scmi_message *message, u32 clk_id);
};

/**
 * struct scmi_perf_ops - represents the various operations provided
 *	by SCMI Performance Protocol
 *
 * @limits_set: sets limits on the performance level of a domain
 * @limits_get: gets limits on the performance level of a domain
 * @level_set: sets the performance level of a domain
 * @level_get: gets the performance level of a domain
 * @device_domain_id: gets the scmi domain id for a given device
 * @transition_latency_get: gets the DVFS transition latency for a given device
 * @device_opps_add: adds all the OPPs for a given device
 * @freq_set: sets the frequency for a given device using sustained frequency
 *	to sustained performance level mapping
 * @freq_get: gets the frequency for a given device using sustained frequency
 *	to sustained performance level mapping
 * @est_power_get: gets the estimated power cost for a given performance domain
 *	at a given frequency
 */
struct scmi_perf_ops {
	int (*limits_set)(const struct scmi_message *message, u32 domain,
			  u32 max_perf, u32 min_perf);
	int (*limits_get)(const struct scmi_message *message, u32 domain,
			  u32 *max_perf, u32 *min_perf);
	int (*level_set)(const struct scmi_message *message, u32 domain,
			 u32 level, bool poll);
	int (*level_get)(const struct scmi_message *message, u32 domain,
			 u32 *level, bool poll);
	int (*freq_set)(const struct scmi_message *message, u32 domain,
			unsigned long rate, bool poll);
	int (*freq_get)(const struct scmi_message *message, u32 domain,
			unsigned long *rate, bool poll);
	int (*est_power_get)(const struct scmi_message *message, u32 domain,
			     unsigned long *rate, unsigned long *power);
	bool (*power_scale_mw_get)(const struct scmi_message *message);
};

/**
 * struct scmi_power_ops - represents the various operations provided
 *	by SCMI Power Protocol
 *
 * @num_domains_get: get the count of power domains provided by SCMI
 * @name_get: gets the name of a power domain
 * @state_set: sets the power state of a power domain
 * @state_get: gets the power state of a power domain
 */
struct scmi_power_ops {
	int (*num_domains_get)(const struct scmi_message *message);
	char *(*name_get)(const struct scmi_message *message, u32 domain);
#define SCMI_POWER_STATE_TYPE_SHIFT	30
#define SCMI_POWER_STATE_ID_MASK	(BIT(28) - 1)
#define SCMI_POWER_STATE_PARAM(type, id) \
	((((type) & BIT(0)) << SCMI_POWER_STATE_TYPE_SHIFT) | \
		((id) & SCMI_POWER_STATE_ID_MASK))
#define SCMI_POWER_STATE_GENERIC_ON	SCMI_POWER_STATE_PARAM(0, 0)
#define SCMI_POWER_STATE_GENERIC_OFF	SCMI_POWER_STATE_PARAM(1, 0)
	int (*state_set)(const struct scmi_message *message, u32 domain,
			 u32 state);
	int (*state_get)(const struct scmi_message *message, u32 domain,
			 u32 *state);
};

/**
 * scmi_sensor_reading  - represent a timestamped read
 *
 * Used by @reading_get_timestamped method.
 *
 * @value: The signed value sensor read.
 * @timestamp: An unsigned timestamp for the sensor read, as provided by
 *	       SCMI platform. Set to zero when not available.
 */
struct scmi_sensor_reading {
	long long value;
	unsigned long long timestamp;
};

/**
 * scmi_range_attrs  - specifies a sensor or axis values' range
 * @min_range: The minimum value which can be represented by the sensor/axis.
 * @max_range: The maximum value which can be represented by the sensor/axis.
 */
struct scmi_range_attrs {
	long long min_range;
	long long max_range;
};

/**
 * scmi_sensor_axis_info  - describes one sensor axes
 * @id: The axes ID.
 * @type: Axes type. Chosen amongst one of @enum scmi_sensor_class.
 * @scale: Power-of-10 multiplier applied to the axis unit.
 * @name: NULL-terminated string representing axes name as advertised by
 *	  SCMI platform.
 * @extended_attrs: Flag to indicate the presence of additional extended
 *		    attributes for this axes.
 * @resolution: Extended attribute representing the resolution of the axes.
 *		Set to 0 if not reported by this axes.
 * @exponent: Extended attribute representing the power-of-10 multiplier that
 *	      is applied to the resolution field. Set to 0 if not reported by
 *	      this axes.
 * @attrs: Extended attributes representing minimum and maximum values
 *	   measurable by this axes. Set to 0 if not reported by this sensor.
 */
struct scmi_sensor_axis_info {
	unsigned int id;
	unsigned int type;
	int scale;
	char name[SCMI_MAX_STR_SIZE];
	bool extended_attrs;
	unsigned int resolution;
	int exponent;
	struct scmi_range_attrs attrs;
};

/**
 * scmi_sensor_intervals_info  - describes number and type of available update
 * intervals
 * @segmented: Flag for segmented intervals' representation. When True there
 *	       will be exactly 3 intervals in @desc, with each entry
 *	       representing a member of a segment in this order:
 *	       {lowest update interval, highest update interval, step size}
 * @count: Number of intervals described in @desc.
 * @desc: Array of @count interval descriptor bitmask represented as detailed in
 *	  the SCMI specification: it can be accessed using the accompanying
 *	  macros.
 * @prealloc_pool: A minimal preallocated pool of desc entries used to avoid
 *		   lesser-than-64-bytes dynamic allocation for small @count
 *		   values.
 */
struct scmi_sensor_intervals_info {
	bool segmented;
	unsigned int count;
#define SCMI_SENS_INTVL_SEGMENT_LOW	0
#define SCMI_SENS_INTVL_SEGMENT_HIGH	1
#define SCMI_SENS_INTVL_SEGMENT_STEP	2
	unsigned int *desc;
#define SCMI_SENS_INTVL_GET_SECS(x)		FIELD_GET(GENMASK(20, 5), (x))
#define SCMI_SENS_INTVL_GET_EXP(x)					\
	({								\
		int __signed_exp = FIELD_GET(GENMASK(4, 0), (x));	\
									\
		if (__signed_exp & BIT(4))				\
			__signed_exp |= GENMASK(31, 5);			\
		__signed_exp;						\
	})
#define SCMI_MAX_PREALLOC_POOL			16
	unsigned int prealloc_pool[SCMI_MAX_PREALLOC_POOL];
};

/**
 * struct scmi_sensor_info - represents information related to one of the
 * available sensors.
 * @id: Sensor ID.
 * @type: Sensor type. Chosen amongst one of @enum scmi_sensor_class.
 * @scale: Power-of-10 multiplier applied to the sensor unit.
 * @num_trip_points: Number of maximum configurable trip points.
 * @async: Flag for asynchronous read support.
 * @update: Flag for continuouos update notification support.
 * @timestamped: Flag for timestamped read support.
 * @tstamp_scale: Power-of-10 multiplier applied to the sensor timestamps to
 *		  represent it in seconds.
 * @num_axis: Number of supported axis if any. Reported as 0 for scalar sensors.
 * @axis: Pointer to an array of @num_axis descriptors.
 * @intervals: Descriptor of available update intervals.
 * @sensor_config: A bitmask reporting the current sensor configuration as
 *		   detailed in the SCMI specification: it can accessed and
 *		   modified through the accompanying macros.
 * @name: NULL-terminated string representing sensor name as advertised by
 *	  SCMI platform.
 * @extended_scalar_attrs: Flag to indicate the presence of additional extended
 *			   attributes for this sensor.
 * @sensor_power: Extended attribute representing the average power
 *		  consumed by the sensor in microwatts (uW) when it is active.
 *		  Reported here only for scalar sensors.
 *		  Set to 0 if not reported by this sensor.
 * @resolution: Extended attribute representing the resolution of the sensor.
 *		Reported here only for scalar sensors.
 *		Set to 0 if not reported by this sensor.
 * @exponent: Extended attribute representing the power-of-10 multiplier that is
 *	      applied to the resolution field.
 *	      Reported here only for scalar sensors.
 *	      Set to 0 if not reported by this sensor.
 * @scalar_attrs: Extended attributes representing minimum and maximum
 *		  measurable values by this sensor.
 *		  Reported here only for scalar sensors.
 *		  Set to 0 if not reported by this sensor.
 */
struct scmi_sensor_info {
	unsigned int id;
	unsigned int type;
	int scale;
	unsigned int num_trip_points;
	bool async;
	bool update;
	bool timestamped;
	int tstamp_scale;
	unsigned int num_axis;
	struct scmi_sensor_axis_info *axis;
	struct scmi_sensor_intervals_info intervals;
	unsigned int sensor_config;
#define SCMI_SENS_CFG_UPDATE_SECS_MASK		GENMASK(31, 16)
#define SCMI_SENS_CFG_GET_UPDATE_SECS(x)				\
	FIELD_GET(SCMI_SENS_CFG_UPDATE_SECS_MASK, (x))

#define SCMI_SENS_CFG_UPDATE_EXP_MASK		GENMASK(15, 11)
#define SCMI_SENS_CFG_GET_UPDATE_EXP(x)					\
	({								\
		int __signed_exp =					\
			FIELD_GET(SCMI_SENS_CFG_UPDATE_EXP_MASK, (x));	\
									\
		if (__signed_exp & BIT(4))				\
			__signed_exp |= GENMASK(31, 5);			\
		__signed_exp;						\
	})

#define SCMI_SENS_CFG_ROUND_MASK		GENMASK(10, 9)
#define SCMI_SENS_CFG_ROUND_AUTO		2
#define SCMI_SENS_CFG_ROUND_UP			1
#define SCMI_SENS_CFG_ROUND_DOWN		0

#define SCMI_SENS_CFG_TSTAMP_ENABLED_MASK	BIT(1)
#define SCMI_SENS_CFG_TSTAMP_ENABLE		1
#define SCMI_SENS_CFG_TSTAMP_DISABLE		0
#define SCMI_SENS_CFG_IS_TSTAMP_ENABLED(x)				\
	FIELD_GET(SCMI_SENS_CFG_TSTAMP_ENABLED_MASK, (x))

#define SCMI_SENS_CFG_SENSOR_ENABLED_MASK	BIT(0)
#define SCMI_SENS_CFG_SENSOR_ENABLE		1
#define SCMI_SENS_CFG_SENSOR_DISABLE		0
	char name[SCMI_MAX_STR_SIZE];
#define SCMI_SENS_CFG_IS_ENABLED(x)		FIELD_GET(BIT(0), (x))
	bool extended_scalar_attrs;
	unsigned int sensor_power;
	unsigned int resolution;
	int exponent;
	struct scmi_range_attrs scalar_attrs;
};

/*
 * Partial list from Distributed Management Task Force (DMTF) specification:
 * DSP0249 (Platform Level Data Model specification)
 */
enum scmi_sensor_class {
	NONE = 0x0,
	UNSPEC = 0x1,
	TEMPERATURE_C = 0x2,
	TEMPERATURE_F = 0x3,
	TEMPERATURE_K = 0x4,
	VOLTAGE = 0x5,
	CURRENT = 0x6,
	POWER = 0x7,
	ENERGY = 0x8,
	CHARGE = 0x9,
	VOLTAMPERE = 0xA,
	NITS = 0xB,
	LUMENS = 0xC,
	LUX = 0xD,
	CANDELAS = 0xE,
	KPA = 0xF,
	PSI = 0x10,
	NEWTON = 0x11,
	CFM = 0x12,
	RPM = 0x13,
	HERTZ = 0x14,
	SECS = 0x15,
	MINS = 0x16,
	HOURS = 0x17,
	DAYS = 0x18,
	WEEKS = 0x19,
	MILS = 0x1A,
	INCHES = 0x1B,
	FEET = 0x1C,
	CUBIC_INCHES = 0x1D,
	CUBIC_FEET = 0x1E,
	METERS = 0x1F,
	CUBIC_CM = 0x20,
	CUBIC_METERS = 0x21,
	LITERS = 0x22,
	FLUID_OUNCES = 0x23,
	RADIANS = 0x24,
	STERADIANS = 0x25,
	REVOLUTIONS = 0x26,
	CYCLES = 0x27,
	GRAVITIES = 0x28,
	OUNCES = 0x29,
	POUNDS = 0x2A,
	FOOT_POUNDS = 0x2B,
	OUNCE_INCHES = 0x2C,
	GAUSS = 0x2D,
	GILBERTS = 0x2E,
	HENRIES = 0x2F,
	FARADS = 0x30,
	OHMS = 0x31,
	SIEMENS = 0x32,
	MOLES = 0x33,
	BECQUERELS = 0x34,
	PPM = 0x35,
	DECIBELS = 0x36,
	DBA = 0x37,
	DBC = 0x38,
	GRAYS = 0x39,
	SIEVERTS = 0x3A,
	COLOR_TEMP_K = 0x3B,
	BITS = 0x3C,
	BYTES = 0x3D,
	WORDS = 0x3E,
	DWORDS = 0x3F,
	QWORDS = 0x40,
	PERCENTAGE = 0x41,
	PASCALS = 0x42,
	COUNTS = 0x43,
	GRAMS = 0x44,
	NEWTON_METERS = 0x45,
	HITS = 0x46,
	MISSES = 0x47,
	RETRIES = 0x48,
	OVERRUNS = 0x49,
	UNDERRUNS = 0x4A,
	COLLISIONS = 0x4B,
	PACKETS = 0x4C,
	MESSAGES = 0x4D,
	CHARS = 0x4E,
	ERRORS = 0x4F,
	CORRECTED_ERRS = 0x50,
	UNCORRECTABLE_ERRS = 0x51,
	SQ_MILS = 0x52,
	SQ_INCHES = 0x53,
	SQ_FEET = 0x54,
	SQ_CM = 0x55,
	SQ_METERS = 0x56,
	RADIANS_SEC = 0x57,
	BPM = 0x58,
	METERS_SEC_SQUARED = 0x59,
	METERS_SEC = 0x5A,
	CUBIC_METERS_SEC = 0x5B,
	MM_MERCURY = 0x5C,
	RADIANS_SEC_SQUARED = 0x5D,
	OEM_UNIT = 0xFF
};

struct scmi_message_header {
	u32 id:8;
	u32 type:2;
	u32 protocol:8;
	u32 token:10;
	u32 zero:4;
};

struct scmi_message_discovery {
	struct scmi_message_header header;
	s32 status;
	u32 response;
};

struct scmi_message_string {
	struct scmi_message_header header;
	s32 status;
	char str[SCMI_MAX_STR_SIZE];
};

struct scmi_message_list_protocols {
	struct scmi_message_header header;
	s32 status;
	u32 count;
	u32 protocols[0];
};

typedef union {
	struct scmi_message_discovery discovery;
	struct scmi_message_string string;
	struct scmi_message_list_protocols protocols;
} scmi_response_t;

typedef struct scmi_message_header scmi_message_header_t;

struct scmi_shared_memory_area {
    u32 reserved0;
    u32 status; // bit 0 is free/busy flag, bit 1 is 'error'
    u64 reserved1;
    u32 flags;
    u32 length;
    scmi_message_header_t header;
    scmi_response_t payload[0];
};

typedef struct scmi_shared_memory_area scmi_shared_memory_area_t;

#endif

