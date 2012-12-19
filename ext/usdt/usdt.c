#include <ruby.h>
#include "usdt.h"

static VALUE USDT;
static VALUE USDT_Provider;
static VALUE USDT_Probe;
static VALUE USDT_Error;

static VALUE provider_create(int argc, VALUE *argv, VALUE self);
static VALUE provider_probe(int argc, VALUE *argv, VALUE self);
static VALUE provider_remove_probe(VALUE self, VALUE probe);
static VALUE provider_enable(VALUE self);
static VALUE provider_disable(VALUE self);
static VALUE probe_enabled(VALUE self);
static VALUE probe_fire(int argc, VALUE *argv, VALUE self);

static void provider_free(void *provider);
static void probe_free(void *probe);

static VALUE t_int;
static VALUE t_str;
static VALUE t_json;

void Init_usdt() {
  USDT = rb_define_module("USDT");

  USDT_Error = rb_define_class_under(USDT, "Error", rb_eRuntimeError);

  USDT_Provider = rb_define_class_under(USDT, "Provider", rb_cObject);
  rb_define_singleton_method(USDT_Provider, "create", provider_create, -1);
  rb_define_method(USDT_Provider, "probe", provider_probe, -1);
  rb_define_method(USDT_Provider, "remove_probe", provider_remove_probe, 1);
  rb_define_method(USDT_Provider, "enable", provider_enable, 0);
  rb_define_method(USDT_Provider, "disable", provider_disable, 0);

  USDT_Probe = rb_define_class_under(USDT, "Probe", rb_cObject);
  rb_define_method(USDT_Probe, "enabled?", probe_enabled, 0);
  rb_define_method(USDT_Probe, "fire", probe_fire, -1);
  rb_define_attr(USDT_Probe, "arguments", 1, 0);

  t_int = ID2SYM(rb_intern("integer"));
  t_str = ID2SYM(rb_intern("string"));
  t_json = ID2SYM(rb_intern("json"));
}

static char *create_module_name(VALUE self, char *module) {
  snprintf(module, sizeof(module), "mod-%p", (void *)self);
  return module;
}

/**
 * USDT::Provider.create :name, :modname?
 */
static VALUE provider_create(int argc, VALUE *argv, VALUE self) {
  const char *name, *mod;
  char module[128];

  if (argc == 0 || argc > 2) {
    rb_raise(USDT_Error, "1 or 2 arguments required; %d provided", argc);
    return Qnil;
  }

  if (RB_TYPE_P(argv[0], T_SYMBOL))
    name = rb_id2name(rb_to_id(argv[0]));
  else if (RB_TYPE_P(argv[0], T_STRING))
    name = RSTRING_PTR(argv[0]);
  else
    rb_raise(USDT_Error, "provider name must be a symbol or string");

  if (argc == 2) {
    if (NIL_P(argv[1]))
      mod = create_module_name(self, module);
    else if (RB_TYPE_P(argv[1], T_SYMBOL))
      mod = rb_id2name(rb_to_id(argv[1]));
    else if (RB_TYPE_P(argv[1], T_STRING))
      mod = RSTRING_PTR(argv[1]);
    else
      rb_raise(USDT_Error, "provider module must be a symbol or string, or nil");
  }
  else {
    mod = create_module_name(self, module);
  }

  usdt_provider_t* p = usdt_create_provider(name, mod);
  VALUE rbProvider = Data_Wrap_Struct(USDT_Provider, NULL, provider_free, p);

  if (rb_block_given_p()) {
    rb_yield(rbProvider);
  }

  return rbProvider;
}

/**
 * USDT::Provider#probe(func, name, pargs*)
 */
static VALUE provider_probe(int argc, VALUE *argv, VALUE self) {
  const char *func, *name;
  size_t i;

  if (argc == 0) {
    rb_raise(USDT_Error, "at least one argument required");
    return Qnil;
  }
  if (argc > 2 + USDT_ARG_MAX) {
    rb_raise(USDT_Error, "maximum number of probe arguments: %d", USDT_ARG_MAX);
    return Qnil;
  }

  if (NIL_P(argv[0]))
    func = "func";
  else if (RB_TYPE_P(argv[0], T_SYMBOL))
    func = rb_id2name(rb_to_id(argv[0]));
  else if (RB_TYPE_P(argv[0], T_STRING))
    func = RSTRING_PTR(argv[0]);
  else
    rb_raise(USDT_Error, "probe function must be a symbol or string, or nil");

  if (RB_TYPE_P(argv[1], T_SYMBOL))
    name = rb_id2name(rb_to_id(argv[1]));
  else if (RB_TYPE_P(argv[1], T_STRING))
    name = RSTRING_PTR(argv[1]);
  else
    rb_raise(USDT_Error, "probe name must be a symbol or string");

  for (i = 0; i < USDT_ARG_MAX; i++)
    if (i < argc - 2)
      Check_Type(argv[i+2], T_SYMBOL);

  usdt_probedef_t **probe = ALLOC(usdt_probedef_t *);

  VALUE rbProbe = Data_Wrap_Struct(USDT_Probe, NULL, probe_free, probe);
  VALUE arguments = rb_ary_new2(USDT_ARG_MAX);
  rb_iv_set(rbProbe, "@arguments", arguments);

  VALUE arg;
  const char *types[USDT_ARG_MAX];

  for (i = 0; i < USDT_ARG_MAX; i++) {
    if (i < argc - 2) {
      if (t_int == ID2SYM(rb_to_id(argv[i+2]))) {
        types[i] = "int";
        rb_ary_push(arguments, t_int);
      }
      else if (t_str == ID2SYM(rb_to_id(argv[i+2]))) {
        types[i] = "char *";
        rb_ary_push(arguments, t_str);
      }
      else if (t_json == ID2SYM(rb_to_id(argv[i+2]))) {
        types[i] = "char *";
        rb_ary_push(arguments, t_json);
      }
      else {
        types[i] = NULL;
      }
    }
    else {
      types[i] = NULL;
    }
  }

  size_t pargc = RARRAY_LEN(arguments);
  *probe = usdt_create_probe(func, name, pargc, types);

  usdt_provider_t *provider = DATA_PTR(self);

  if ((usdt_provider_add_probe(provider, *probe) == 0)) {
    return rbProbe;
  }
  else {
    rb_raise(USDT_Error, "%s", usdt_errstr(provider));
    return Qnil;
  }
}

/**
 * USDT::Provider#remove_probe(probe)
 */
static VALUE provider_remove_probe(VALUE self, VALUE probe) {
  if (rb_class_of(probe) != USDT_Probe)
    rb_raise(USDT_Error, "argument to remove_probe must be a Probe object");

  usdt_provider_t *provider = DATA_PTR(self);
  usdt_probedef_t **p = DATA_PTR(probe);
  usdt_probedef_t *probedef = *p;

  usdt_provider_remove_probe(provider, probedef);

  return Qtrue;
}

/**
 * USDT::Provider#enable
 */
static VALUE provider_enable(VALUE self) {
  usdt_provider_t *provider = DATA_PTR(self);
  int status = usdt_provider_enable(provider);

  if (status == 0)
    return Qtrue;
  else
    rb_raise(USDT_Error, "%s", usdt_errstr(provider));
}

/**
 * USDT::Provider#disable
 */
static VALUE provider_disable(VALUE self) {
  usdt_provider_t *provider = DATA_PTR(self);
  int status = usdt_provider_disable(provider);
  if (status == 0) {
    return Qtrue;
  } else {
    rb_raise(USDT_Error, "%s", usdt_errstr(provider));
    return Qnil;
  }
}

/**
 * USDT::Probe#enabled?
 */
static VALUE probe_enabled(VALUE self) {
  usdt_probedef_t **p = DATA_PTR(self);
  usdt_probedef_t *pd = *p;

  if (usdt_is_enabled(pd->probe) == 0)
    return Qfalse;
  else
    return Qtrue;
}

/**
 * USDT::Probe#fire *args
 */
static VALUE probe_fire(int argc, VALUE *argv, VALUE self) {
  usdt_probedef_t **p = DATA_PTR(self);
  usdt_probedef_t *probedef = *p;

  void *pargs[USDT_ARG_MAX];
  size_t i;

  if (probe_enabled(self) == Qfalse)
    return Qfalse;

  for (i = 0; i < probedef->argc; i++) {
    VALUE arg = RARRAY_PTR(rb_iv_get(self, "@arguments"))[i];

    if (arg == t_str) {
      Check_Type(argv[i], T_STRING);
      pargs[i] = (void *) RSTRING_PTR(argv[i]);
    }
    else if (arg == t_int) {
      Check_Type(argv[i], T_FIXNUM);
      pargs[i] = (void *) FIX2INT(argv[i]);
    }
    else if (arg == t_json) {
      VALUE json = rb_funcall(argv[i], rb_intern("to_json"), 0);
      pargs[i] = (void *) RSTRING_PTR(json);
    }
    else {
      pargs[i] = NULL;
    }
  }

  usdt_fire_probe(probedef->probe, probedef->argc, pargs);
  return Qtrue;
}

static void provider_free(void *p) {
  usdt_provider_t *provider = p;
  usdt_provider_disable(provider);
  usdt_provider_free(provider);
}

static void probe_free(void *p) {
  usdt_probedef_t **probedef = p;
  usdt_probe_release(*probedef);
}
