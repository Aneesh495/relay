"""
AST Tree-Walking Interpreter for Relay BASIC with SCADA Intrinsics.
"""

import math
import time
from typing import Dict, Any, List, Optional
from .parser import (
    ASTNode, ProgramNode, DimNode, TypeDefNode, SubDefNode, AssignNode,
    IfNode, WhileNode, ForNode, PrintNode, ReturnNode, CallNode,
    BinaryOpNode, UnaryOpNode, LiteralNode, VariableNode, ArrayAccessNode, FieldAccessNode
)
from .lexer import TokenType

class ReturnException(Exception):
    def __init__(self, value: Any):
        self.value = value

class Environment:
    def __init__(self, parent: Optional["Environment"] = None):
        self.parent = parent
        self.values: Dict[str, Any] = {}

    def get(self, name: str) -> Any:
        uname = name.upper()
        if uname in self.values:
            return self.values[uname]
        if self.parent:
            return self.parent.get(name)
        return 0.0

    def set(self, name: str, val: Any):
        uname = name.upper()
        if uname in self.values:
            self.values[uname] = val
            return
        if self.parent and self.parent.has(name):
            self.parent.set(name, val)
            return
        self.values[uname] = val

    def has(self, name: str) -> bool:
        uname = name.upper()
        if uname in self.values:
            return True
        if self.parent:
            return self.parent.has(name)
        return False

class TagRecord:
    def __init__(self, name: str, tag_type: int, units: str, eu_min: float, eu_max: float):
        self.name = name
        self.tag_type = tag_type
        self.units = units
        self.eu_min = eu_min
        self.eu_max = eu_max
        self.value = eu_min
        self.quality = 192  # GOOD
        self.timestamp_ms = int(time.time() * 1000)

class SdtSeries:
    def __init__(self, tag_id: int, comp_dev: float, min_ms: int, max_ms: int):
        self.tag_id = tag_id
        self.comp_dev = comp_dev
        self.min_ms = min_ms
        self.max_ms = max_ms
        self.samples: List[tuple] = []  # (ts, val, q)
        self.last_archived: Optional[tuple] = None
        self.prev_point: Optional[tuple] = None
        self.slope_upper = 1e30
        self.slope_lower = -1e30

class Interpreter:
    def __init__(self):
        self.global_env = Environment()
        self.subroutines: Dict[str, SubDefNode] = {}
        self.types: Dict[str, TypeDefNode] = {}
        self.output_buffer: List[str] = []

        # SCADA Data Fabric
        self.tags: List[TagRecord] = []
        self.historian_series: List[SdtSeries] = []

        self._register_intrinsics()

    def _register_intrinsics(self):
        # Register standard math and timing intrinsics in global environment
        pass

    def run(self, node: ASTNode) -> Any:
        return self._execute(node, self.global_env)

    def _execute(self, node: ASTNode, env: Environment) -> Any:
        if isinstance(node, ProgramNode):
            res = None
            for stmt in node.statements:
                res = self._execute(stmt, env)
            return res

        if isinstance(node, DimNode):
            dim_size = 0
            if node.array_dim:
                dim_size = int(self._evaluate(node.array_dim, env))
                env.values[node.name.upper()] = [0.0] * max(1, dim_size)
            else:
                default_val = 0.0
                if node.var_type.upper() == "STRING":
                    default_val = ""
                elif node.var_type.upper() in self.types:
                    t_def = self.types[node.var_type.upper()]
                    default_val = {f_name.upper(): 0.0 for f_name, _ in t_def.fields}
                env.values[node.name.upper()] = default_val
            return None

        if isinstance(node, TypeDefNode):
            self.types[node.name.upper()] = node
            return None

        if isinstance(node, SubDefNode):
            self.subroutines[node.name.upper()] = node
            return None

        if isinstance(node, AssignNode):
            val = self._evaluate(node.expr, env)
            if isinstance(node.target, VariableNode):
                env.set(node.target.name, val)
            elif isinstance(node.target, CallNode):
                # Target is array element arr(idx)
                arr = env.get(node.target.name)
                if isinstance(arr, list) and len(node.target.args) > 0:
                    idx = int(self._evaluate(node.target.args[0], env))
                    if 0 <= idx < len(arr):
                        arr[idx] = val
                    elif idx >= len(arr):
                        arr.extend([0.0] * (idx - len(arr) + 1))
                        arr[idx] = val
            elif isinstance(node.target, FieldAccessNode):
                rec = self._evaluate(node.target.record_expr, env)
                if isinstance(rec, dict):
                    rec[node.target.field_name.upper()] = val
            return None

        if isinstance(node, IfNode):
            cond_val = self._evaluate(node.condition, env)
            if self._is_truthy(cond_val):
                for s in node.then_body:
                    self._execute(s, env)
            else:
                for s in node.else_body:
                    self._execute(s, env)
            return None

        if isinstance(node, WhileNode):
            while self._is_truthy(self._evaluate(node.condition, env)):
                for s in node.body:
                    self._execute(s, env)
            return None

        if isinstance(node, ForNode):
            start = self._evaluate(node.start_expr, env)
            end = self._evaluate(node.end_expr, env)
            step = 1.0 if not node.step_expr else self._evaluate(node.step_expr, env)

            curr = start
            env.set(node.var_name, curr)
            while (step > 0 and curr <= end) or (step < 0 and curr >= end):
                for s in node.body:
                    self._execute(s, env)
                curr += step
                env.set(node.var_name, curr)
            return None

        if isinstance(node, PrintNode):
            parts = [str(self._evaluate(e, env)) for e in node.expressions]
            text = " ".join(parts)
            if node.newline:
                text += "\n"
            self.output_buffer.append(text)
            print(text, end="")
            return None

        if isinstance(node, ReturnNode):
            val = None
            if node.expr:
                val = self._evaluate(node.expr, env)
            raise ReturnException(val)

        return self._evaluate(node, env)

    def _evaluate(self, node: ASTNode, env: Environment) -> Any:
        if isinstance(node, LiteralNode):
            return node.value

        if isinstance(node, VariableNode):
            return env.get(node.name)

        if isinstance(node, CallNode):
            return self._call_subroutine(node.name, node.args, env)

        if isinstance(node, FieldAccessNode):
            rec = self._evaluate(node.record_expr, env)
            if isinstance(rec, dict):
                return rec.get(node.field_name.upper(), 0.0)
            return 0.0

        if isinstance(node, UnaryOpNode):
            val = self._evaluate(node.operand, env)
            if node.op == TokenType.MINUS:
                return -val
            if node.op == TokenType.NOT:
                return 0 if self._is_truthy(val) else 1
            return val

        if isinstance(node, BinaryOpNode):
            left = self._evaluate(node.left, env)
            right = self._evaluate(node.right, env)

            if node.op == TokenType.PLUS:
                if isinstance(left, str) or isinstance(right, str):
                    return str(left) + str(right)
                return left + right
            if node.op == TokenType.MINUS:
                return left - right
            if node.op == TokenType.STAR:
                return left * right
            if node.op == TokenType.SLASH:
                return (left / right) if abs(right) > 1e-15 else 0.0
            if node.op == TokenType.BACKSLASH:
                return int(left // right) if right != 0 else 0
            if node.op == TokenType.MOD:
                return int(left % right) if right != 0 else 0
            if node.op == TokenType.CARET:
                return math.pow(left, right)

            if node.op == TokenType.EQUAL:
                return 1 if left == right else 0
            if node.op == TokenType.NOT_EQUAL:
                return 1 if left != right else 0
            if node.op == TokenType.LESS:
                return 1 if left < right else 0
            if node.op == TokenType.LESS_EQUAL:
                return 1 if left <= right else 0
            if node.op == TokenType.GREATER:
                return 1 if left > right else 0
            if node.op == TokenType.GREATER_EQUAL:
                return 1 if left >= right else 0

            if node.op == TokenType.AND:
                return int(left) & int(right)
            if node.op == TokenType.OR:
                return int(left) | int(right)
            if node.op == TokenType.XOR:
                return int(left) ^ int(right)

        return 0.0

    def _call_subroutine(self, name: str, args: List[ASTNode], env: Environment) -> Any:
        uname = name.upper()

        # Check for array access syntax: arr(index)
        if env.has(name) and isinstance(env.get(name), list):
            arr = env.get(name)
            if len(args) > 0:
                idx = int(self._evaluate(args[0], env))
                if 0 <= idx < len(arr):
                    return arr[idx]
                return 0.0
            return arr

        # Host SCADA & Math Intrinsics
        arg_vals = [self._evaluate(a, env) for a in args]

        if uname == "CLOCK_MS":
            return int(time.time() * 1000)
        if uname == "CLOCK_MICROS":
            return int(time.time() * 1000000)
        if uname == "SLEEP_MS":
            if len(arg_vals) > 0 and arg_vals[0] > 0:
                time.sleep(arg_vals[0] / 1000.0)
            return None

        # Math Library
        if uname == "SIN":
            return math.sin(arg_vals[0] if arg_vals else 0.0)
        if uname == "COS":
            return math.cos(arg_vals[0] if arg_vals else 0.0)
        if uname == "TAN":
            return math.tan(arg_vals[0] if arg_vals else 0.0)
        if uname == "ATN":
            return math.atan(arg_vals[0] if arg_vals else 0.0)
        if uname == "EXP":
            return math.exp(arg_vals[0] if arg_vals else 0.0)
        if uname == "LOG":
            v = arg_vals[0] if arg_vals else 1.0
            return math.log(v) if v > 0 else 0.0
        if uname == "SQR":
            v = arg_vals[0] if arg_vals else 0.0
            return math.sqrt(v) if v >= 0 else 0.0
        if uname == "ABS":
            return abs(arg_vals[0] if arg_vals else 0.0)
        if uname == "SGN":
            v = arg_vals[0] if arg_vals else 0.0
            return 1 if v > 0 else (-1 if v < 0 else 0)
        if uname == "RND":
            import random
            return random.random()
        if uname == "MIN":
            return min(arg_vals[0], arg_vals[1]) if len(arg_vals) >= 2 else (arg_vals[0] if arg_vals else 0.0)
        if uname == "MAX":
            return max(arg_vals[0], arg_vals[1]) if len(arg_vals) >= 2 else (arg_vals[0] if arg_vals else 0.0)
        if uname == "CLAMP":
            if len(arg_vals) >= 3:
                return max(arg_vals[1], min(arg_vals[2], arg_vals[0]))
            return arg_vals[0] if arg_vals else 0.0
        if uname == "LERP":
            if len(arg_vals) >= 3:
                return arg_vals[0] + arg_vals[2] * (arg_vals[1] - arg_vals[0])
            return 0.0

        # String Library
        if uname == "LEN":
            return len(str(arg_vals[0])) if arg_vals else 0
        if uname in ("MID$", "MID"):
            s = str(arg_vals[0])
            start = int(arg_vals[1]) if len(arg_vals) > 1 else 1
            length = int(arg_vals[2]) if len(arg_vals) > 2 else len(s)
            return s[start - 1 : start - 1 + length]
        if uname in ("LEFT$", "LEFT"):
            s = str(arg_vals[0])
            n = int(arg_vals[1]) if len(arg_vals) > 1 else len(s)
            return s[:n]
        if uname in ("RIGHT$", "RIGHT"):
            s = str(arg_vals[0])
            n = int(arg_vals[1]) if len(arg_vals) > 1 else len(s)
            return s[-n:] if n > 0 else ""
        if uname in ("STR$", "STR"):
            return str(arg_vals[0])
        if uname == "VAL":
            try:
                return float(arg_vals[0])
            except ValueError:
                return 0.0
        if uname in ("UCASE$", "UCASE"):
            return str(arg_vals[0]).upper()
        if uname in ("LCASE$", "LCASE"):
            return str(arg_vals[0]).lower()
        if uname in ("TRIM$", "TRIM"):
            return str(arg_vals[0]).strip()
        if uname in ("CHR$", "CHR"):
            return chr(int(arg_vals[0]))
        if uname == "ASC":
            s = str(arg_vals[0])
            return ord(s[0]) if s else 0

        # SCADA Tag Engine Intrinsics
        if uname == "TAG_REGISTER":
            # (name, type, units, min_eu, max_eu)
            name_str = str(arg_vals[0])
            t_type = int(arg_vals[1])
            units_str = str(arg_vals[2])
            min_eu = float(arg_vals[3])
            max_eu = float(arg_vals[4])
            t_rec = TagRecord(name_str, t_type, units_str, min_eu, max_eu)
            self.tags.append(t_rec)
            return len(self.tags) - 1

        if uname == "TAG_READ":
            tag_id = int(arg_vals[0])
            if 0 <= tag_id < len(self.tags):
                return self.tags[tag_id].value
            return 0.0

        if uname == "TAG_WRITE":
            tag_id = int(arg_vals[0])
            val = float(arg_vals[1])
            if 0 <= tag_id < len(self.tags):
                self.tags[tag_id].value = val
                self.tags[tag_id].timestamp_ms = int(time.time() * 1000)
                return 1
            return 0

        if uname == "TAG_GET_QUALITY":
            tag_id = int(arg_vals[0])
            if 0 <= tag_id < len(self.tags):
                return self.tags[tag_id].quality
            return 0

        if uname == "TAG_SET_QUALITY":
            tag_id = int(arg_vals[0])
            q = int(arg_vals[1])
            if 0 <= tag_id < len(self.tags):
                self.tags[tag_id].quality = q
                return 1
            return 0

        # Historian & SDT Intrinsics
        if uname == "HIST_REGISTER":
            tag_id = int(arg_vals[0])
            comp_dev = float(arg_vals[1])
            min_ms = int(arg_vals[2]) if len(arg_vals) > 2 else 10
            max_ms = int(arg_vals[3]) if len(arg_vals) > 3 else 60000
            s = SdtSeries(tag_id, comp_dev, min_ms, max_ms)
            self.historian_series.append(s)
            return len(self.historian_series) - 1

        if uname == "HIST_INGEST":
            sid = int(arg_vals[0])
            ts = int(arg_vals[1])
            val = float(arg_vals[2])
            q = int(arg_vals[3]) if len(arg_vals) > 3 else 192

            if 0 <= sid < len(self.historian_series):
                s = self.historian_series[sid]
                curr = (ts, val, q)
                if not s.last_archived:
                    s.last_archived = curr
                    s.prev_point = curr
                    s.samples.append(curr)
                    return 1

                dt = ts - s.last_archived[0]
                if dt < s.min_ms:
                    s.prev_point = curr
                    return 1

                if dt >= s.max_ms:
                    if s.prev_point and s.prev_point[0] > s.last_archived[0]:
                        s.samples.append(s.prev_point)
                    s.samples.append(curr)
                    s.last_archived = curr
                    s.prev_point = curr
                    s.slope_upper = 1e30
                    s.slope_lower = -1e30
                    return 1

                dt_sec = max(1e-6, dt / 1000.0)
                s_upper = (val - s.last_archived[1] + s.comp_dev) / dt_sec
                s_lower = (val - s.last_archived[1] - s.comp_dev) / dt_sec

                if s_upper < s.slope_upper:
                    s.slope_upper = s_upper
                if s_lower > s.slope_lower:
                    s.slope_lower = s_lower

                if s.slope_upper < s.slope_lower:
                    if s.prev_point and s.prev_point[0] > s.last_archived[0]:
                        s.samples.append(s.prev_point)
                        s.last_archived = s.prev_point
                    dt = ts - s.last_archived[0]
                    dt_sec = max(1e-6, dt / 1000.0)
                    s.slope_upper = (val - s.last_archived[1] + s.comp_dev) / dt_sec
                    s.slope_lower = (val - s.last_archived[1] - s.comp_dev) / dt_sec

                s.prev_point = curr
                return 1
            return 0

        if uname == "HIST_TWA":
            sid = int(arg_vals[0])
            t0 = int(arg_vals[1])
            t1 = int(arg_vals[2])
            if 0 <= sid < len(self.historian_series):
                samples = self.historian_series[sid].samples
                if len(samples) < 2:
                    return samples[0][1] if samples else 0.0
                total_area = 0.0
                total_time = 0
                for i in range(len(samples) - 1):
                    p0 = samples[i]
                    p1 = samples[i + 1]
                    if p1[0] < t0 or p0[0] > t1:
                        continue
                    ts_start = max(t0, p0[0])
                    ts_end = min(t1, p1[0])
                    if ts_end > ts_start:
                        dt = ts_end - ts_start
                        y_avg = (p0[1] + p1[1]) * 0.5
                        total_area += y_avg * dt
                        total_time += dt
                return (total_area / total_time) if total_time > 0 else 0.0
            return 0.0

        # Modbus CRC-16
        if uname == "MODBUS_CRC":
            data = arg_vals[0]
            if isinstance(data, str):
                data = data.encode("utf-8")
            crc = 0xFFFF
            for byte in data:
                crc ^= byte
                for _ in range(8):
                    if (crc & 0x0001) != 0:
                        crc >>= 1
                        crc ^= 0xA001
                    else:
                        crc >>= 1
            return crc

        # User-Defined Subroutines
        if uname in self.subroutines:
            sub = self.subroutines[uname]
            call_env = Environment(parent=self.global_env)
            for i, (p_name, _) in enumerate(sub.params):
                val = arg_vals[i] if i < len(arg_vals) else 0.0
                call_env.values[p_name.upper()] = val

            try:
                for s in sub.body:
                    self._execute(s, call_env)
            except ReturnException as ret:
                return ret.value
            return None

        # Unknown function
        return 0.0

    def _is_truthy(self, val: Any) -> bool:
        if isinstance(val, (int, float)):
            return val != 0
        if isinstance(val, bool):
            return val
        if isinstance(val, str):
            return len(val) > 0
        return bool(val)
