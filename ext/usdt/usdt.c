#include <ruby.h>
#include "usdt.h"

static VALUE USDT;
static VALUE USDT_Provider;
static VALUE USDT_Probe;
static VALUE USDT_Error;
static VALUE cJSON;

static VALUE provider_create(VALUE self, VALUE name, VALUE mod);
static VALUE provider_probe(int argc, VALUE *argv, VALUE self);
static VALUE provider_remove_probe(VALUE self, VALUE probe);
static VALUE provider_enable(VALUE self);
static VALUE provider_disable(VALUE self);
static VALUE probe_enabled(VALUE self);
static VALUE probe_fire(int argc, VALUE *argv, VALUE self);

static VALUE t_int;
static VALUE t_str;
static VALUE t_json;

void Init_usdt() {
  USDT = rb_define_module("USDT");

  USDT_Error = rb_define_class_under(USDT, "Error", rb_eRuntimeError);

  USDT_Provider = rb_define_class_under(USDT, "Provider", rb_cObject);
  rb_define_singleton_method(USDT_Provider, "create", provider_create, 2);
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

  cJSON = rb_const_get(rb_cObject, rb_intern("JSON"));
}

/**
 * USDT::Provider.create :name, :modname
 */
static VALUE provider_create(VALUE self, VALUE name, VALUE mod) {
  Check_Type(name, T_SYMBOL);
  Check_Type(mod, T_SYMBOL);

  const char *namestr = rb_id2name(rb_to_id(name));
  const char *modstr = rb_id2name(rb_to_id(mod));

  usdt_provider_t* p = usdt_create_provider(namestr, modstr);

  VALUE rbProvider = Data_Wrap_Struct(USDT_Provider, NULL, free, p);

  if (rb_block_given_p()) {
    rb_yield(rbProvider);
  }

  return rbProvider;
}

/**
 * USDT::Provider#probe(func, name, pargs*)
 */
static VALUE provider_probe(int argc, VALUE *argv, VALUE self) {
  const char *func = rb_id2name(rb_to_id(argv[0]));
  const char *name = rb_id2name(rb_to_id(argv[1]));
  const char *types[USDT_ARG_MAX];
  size_t i;

  usdt_probedef_t **probe;
  probe = ALLOC(usdt_probedef_t *);

  VALUE rbProbe = Data_Wrap_Struct(USDT_Probe, NULL, free, probe);
  VALUE arguments = rb_ary_new2(USDT_ARG_MAX);
  rb_iv_set(rbProbe, "@arguments", arguments);

  VALUE arg;
  for (i = 0; i < USDT_ARG_MAX; i++) {
    if (i < argc - 2) {
      Check_Type(argv[i+2], T_SYMBOL);

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
      VALUE json = rb_funcall(cJSON, rb_intern("generate"), 1, argv[i]);
      pargs[i] = (void *) RSTRING_PTR(json);
    }
    else {
      pargs[i] = NULL;
    }
  }

  usdt_fire_probe(probedef->probe, probedef->argc, pargs);
  return Qtrue;
}
