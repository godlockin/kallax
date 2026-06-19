// 跟 v2.7.4 D4.5 联合, 跟 Rule 8 联合. Split from main.rs.
// Output formatting: text + JSON + YAML.

use crate::main::OutputFormat;
use serde_json::Value;

pub fn output_result(format: OutputFormat, action: &str, data: serde_json::Value) {
    match format {
        OutputFormat::Json => {
            let envelope = serde_json::json!({
                "action": action,
                "status": "ok",
                "data": data,
            });
            println!("{}", serde_json::to_string_pretty(&envelope).unwrap_or_default());
        }
        OutputFormat::Yaml => {
            let envelope = serde_yaml_or_json(&data);
            println!("action: {}\nstatus: ok\ndata: {}", action, envelope);
        }
        OutputFormat::Text => {
            println!("Action: {} (ok)", action);
            print_json_as_text(&data, 1);
        }
    }
}

fn serde_yaml_or_json(v: &Value) -> String {
    serde_json::to_string_pretty(v).unwrap_or_default()
}

pub fn print_json_as_text(value: &Value, indent: usize) {
    let prefix = "  ".repeat(indent);
    match value {
        Value::Object(map) => {
            for (k, v) in map {
                println!("{}{}: {}", prefix, k, format_value(v));
            }
        }
        Value::Array(arr) => {
            for (i, v) in arr.iter().enumerate() {
                println!("{}[{}]: {}", prefix, i, format_value(v));
            }
        }
        _ => println!("{}{}", prefix, format_value(value)),
    }
}

pub fn format_value(value: &Value) -> String {
    match value {
        Value::Null => "null".to_string(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => n.to_string(),
        Value::String(s) => s.clone(),
        Value::Array(arr) => format!("[{} items]", arr.len()),
        Value::Object(obj) => format!("{{{} keys}}", obj.len()),
    }
}
