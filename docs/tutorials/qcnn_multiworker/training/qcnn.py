# Copyright 2021 The TensorFlow Quantum Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

from __future__ import absolute_import, division, print_function, unicode_literals
import cirq
import tensorflow as tf
import os
import argparse, datetime
from google.cloud import storage


strategy = tf.distribute.experimental.MultiWorkerMirroredStrategy()

# Must be imported after MultiWorkerMirroredStrategy instantiation
import tensorflow_quantum as tfq
import qcnn_common

def upload_blob(bucket_name, source_file_name, destination_blob_name):
    """Uploads a file to the bucket."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)

    blob.upload_from_filename(source_file_name)

    print(
        "File {} uploaded to {}.".format(
            source_file_name, destination_blob_name
        )
    )

def main(args):
  print("TF_CONFIG:")
  print(os.environ['TF_CONFIG'])

  qcnn_model, train_excitations, train_labels, _, _ = qcnn_common.prepare_model(strategy)
  opt = tf.keras.optimizers.Adam(learning_rate=0.02)
  qcnn_model.compile(optimizer=opt,
                     loss=tf.losses.mse,
                     metrics=['accuracy'])

  tensorboard_callback = tf.keras.callbacks.TensorBoard(log_dir=args.logdir,
                                                        histogram_freq=1,
                                                        profile_batch='10,20')

  history = qcnn_model.fit(x=train_excitations,
                           y=train_labels,
                           batch_size=32,
                           epochs=50,
                           verbose=1,
                           callbacks=[tensorboard_callback])

  task_type, task_id = (strategy.cluster_resolver.task_type,
                        strategy.cluster_resolver.task_id)
  if task_type == 'worker' and task_id == 0:
    qcnn_weights_path='/tmp/qcnn_weights.h5'
    qcnn_model.save_weights(qcnn_weights_path)
    #ts = str(datetime.datetime.now())
    upload_blob(args.weights_gcs_bucket, qcnn_weights_path, f'qcnn_weights.h5')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--weights-gcs-bucket', help='Name of the GCS bucket for storing training weights.')
    parser.add_argument(
        '--logdir', help='Log directory for Tensorboard.')
    parser.add_argument(
        '--profiler-port', help='The port at which the Tensorflow profiler listens.', type=int)

    args, _ = parser.parse_known_args()

    main(args)
