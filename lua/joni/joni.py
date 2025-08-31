import json
import argparse
from jinja2 import Environment, PackageLoader, select_autoescape
from pathlib import Path


class JsonToUnitTest:
    def __init__(
        self,
        jsonName,
        urlName,
        methodName,
        responseCode=200,
        template='flutter-test.jinja'
    ):
        self.jsonName = jsonName
        self.urlName = urlName
        self.methodName = methodName
        self.responseCode = responseCode

        self.env = Environment(
            loader=PackageLoader("joni", "templates"),
            autoescape=select_autoescape()
        )
        self.template = self.env.get_template(template)

    def _toCamelCase(self, string):
        """Changes the input [string] to a camel case format.

        Args:
            string: A string in snake_case format

        Returns:
            A String in camelCase format"""
        return "".join(x.capitalize() for x in string.lower().split("_"))

    def _toLowerCamelCase(self, string):
        """Changes the input [string] to a lower camel case format.

        Args:
            string: A string in snake_case format

        Returns:
            A String in camelCase format"""
        camel_str = self._toCamelCase(string)
        return string[0].lower() + camel_str[1:]

    def _toUpperCamelCase(self, string):
        """Changes the input [string] to a camel case format.

        Args:
            string: A string in snake_case format

        Returns:
            A String in CamelCase format"""
        camel_str = self._toCamelCase(string)
        return string[0].upper() + camel_str[1:] + "Response"

    def _parseJsons(self, json):
        pass

    def extract_attrs(self, obj, parent_key='', separator='.'):
        """Extract primitive attributes"""

        attrs = []
        if isinstance(obj, dict):
            for key, value in obj.items():

                child_key = key

                if parent_key:
                    child_key = f'{parent_key}{separator}{key}'

                if isinstance(value, dict):
                    child_attrs = self.extract_attrs(
                        value,
                        child_key,
                        separator
                    )

                    attrs.extend(child_attrs)

                elif isinstance(value, list):
                    if len(value) <= 0:
                        attrs.append({
                            'name': self._toLowerCamelCase(child_key),
                            'value': ""
                        })
                        continue

                    if isinstance(value[0], dict):
                        child_attrs = self.extract_attrs(
                            value[0],
                            child_key,
                            separator
                        )

                        attrs.extend(child_attrs)
                    else:
                        attrs.append({
                            'name': self._toLowerCamelCase(child_key),
                            'value': value
                        })

                else:
                    attrs.append({
                        'name': self._toLowerCamelCase(child_key),
                        'value': f'"{value}"' if type(value) is str else value
                    })

        return attrs

    def generate_response(self, name, obj):
        return {
            'name': self.urlName,
            'statusCode': self.responseCode,
            'jsonName': name,
            'attrs': self.extract_attrs(obj),
        }

    def render(self, obj=None):
        if (obj is None):
            obj = self.jsonName

        with open(obj) as f:
            name = obj.split('/')[-1].split('.')[0]
            jsonFile = json.load(f)

            response = self.generate_response(name, jsonFile)
            method = {'name': self.methodName}

            print(self.template.render(
                response=response,
                method=method
            ))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate Flutter test file from a JSON."
    )
    parser.add_argument("jsonName", help="Name of the JSON file to use")
    parser.add_argument("urlName", help="Name of the URL endpoint")
    parser.add_argument("methodName", help="Name of your Method")

    parser.add_argument("--responseCode", type=int, default=200,
                        help="HTTP response code \
                        (default: 200)")
    parser.add_argument("--template", default="flutter-test.jinja",
                        help="Jinja template file \
                        (default: flutter-test.jinja)")

    args = parser.parse_args()

    jsonToUnitTest = JsonToUnitTest(
        args.jsonName,
        args.urlName,
        args.methodName,
        args.responseCode,
        args.template,
    )

    jsonToUnitTest.render()
