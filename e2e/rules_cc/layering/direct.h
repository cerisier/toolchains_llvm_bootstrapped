#ifndef E2E_RULES_CC_LAYERING_DIRECT_H_
#define E2E_RULES_CC_LAYERING_DIRECT_H_

#include "layering/transitive.h"

inline int direct_value() {
  return transitive_value();
}

#endif  // E2E_RULES_CC_LAYERING_DIRECT_H_
